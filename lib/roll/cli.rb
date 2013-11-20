require 'open3'
require 'ostruct'

module Roll
  class Cli < Thor
    include Thor::Actions

    desc 'create', 'Create roll project'
    def create(project = 'roll')
      do_create(project)
    end

    desc 'deploy [--sudo] cluster|host|user@host:port [role]', 'Deploy roll project on the host(s)'
    method_options :sudo => false
    def deploy(target, role = nil)
      do_deploy(target, role, options.sudo?)
    end

    desc 'execute [--sudo] cluster|host|user@host:port script [<args>]', 'Execute a script on the host(s).'
    method_options :sudo => false
    def execute(target, script, *args)
      script = "scripts/#{script}"
      do_execute(target, script, options.sudo?, args)
    end

    desc 'compile', 'Compile roll project'
    def compile(role = nil)
      do_compile(role)
    end

    desc 'setup [linode|digital_ocean]', 'Setup a new VM'
    def setup(provider)
      Roll::Cloud.new(self, provider).setup
    end

    desc 'teardown [linode|digital_ocean] [name]', 'Teardown an existing VM'
    def teardown(provider, name)
      Roll::Cloud.new(self, provider).teardown(name)
    end

    desc 'version', 'Show version'
    def version
      puts Gem.loaded_specs['roll'].version.to_s
    end

    no_tasks do
      include Roll::Utility

      def self.source_root
        File.expand_path('../../',__FILE__)
      end

      def do_create(project)
        copy_file 'templates/create/.gitignore',         "#{project}/.gitignore"
        copy_file 'templates/create/roll.yml',           "#{project}/roll.yml"
        copy_file 'templates/create/install.sh',         "#{project}/install.sh"
        copy_file 'templates/create/roll.sh',            "#{project}/roll.sh"
        copy_file 'templates/create/config.sh',          "#{project}/config.sh"
        copy_file 'templates/create/scripts/update.sh',  "#{project}/scripts/update.sh"
        copy_file 'templates/create/roles/db.sh',        "#{project}/roles/db.sh"
        copy_file 'templates/create/roles/web.sh',       "#{project}/roles/web.sh"
        copy_file 'templates/create/files/.gitkeep',     "#{project}/files/.gitkeep"
      end

      def do_execute(target, script, force_sudo, args=nil)
        get_config()
        sudo = 'sudo ' if force_sudo
        hosts(target).each do |name, machine|
          user, host, port = parse_target(machine)

          if target == machine
            name = host
          end

          endpoint = "#{user}@#{host}"

          `ssh-keygen -q -R #{host} 2> /dev/null`

          remote_commands = <<-EOS
          rm -rf ~/roll &&
          mkdir ~/roll &&
          cd ~/roll &&
          tar xmz &&
          echo "ROLL_NAME=\"#{name}\"\nROLL_HOST=\"#{host}\"\nROLL_USER=\"#{user}\"\n" >> config.sh &&
          #{sudo}ROLL_NAME="#{name}" ROLL_HOST="#{host}" ROLL_USER="#{user}" bash #{script} #{args}
          EOS

          remote_commands.strip! << ' && rm -rf ~/roll' if @config['preferences'] and @config['preferences']['erase_remote_folder']

          local_commands = <<-EOS
          cd compiled
          tar cz . | ssh -q -o 'StrictHostKeyChecking no' #{endpoint} -p #{port} '#{remote_commands}'
          EOS

          Open3.popen3(local_commands) do |stdin, stdout, stderr|
            stdin.close
            t = Thread.new do
              while (line = stderr.gets)
                print line.color(:red)
              end
            end
            while (line = stdout.gets)
              print line.color(:green)
            end
            t.join
          end
        end
      end

      def do_deploy(target, role, force_sudo)
        # compile attributes and scripts
        do_compile(role)

        # run the install script
        do_execute(target, "install.sh", force_sudo)
      end

      def do_compile(role)
        get_config()

        # Check if role exists
        abort_with "#{role} doesn't exist!" if role and !File.exists?("roles/#{role}.sh")

        # Break down attributes into individual files
        (@config['attributes'] || {}).each {|key, value| create_file "compiled/attributes/#{key}", value }

        # Retrieve remote scripts via HTTP
        cache_remote_scripts = @config['preferences'] && @config['preferences']['cache_remote_scripts']
        (@config['scripts'] || []).each do |key, value|
          next if cache_remote_scripts and File.exists?("compiled/scripts/#{key}.sh")
          get value, "compiled/scripts/#{key}.sh"
        end

        # Copy local files
        @attributes = OpenStruct.new(@config['attributes'])
        copy_or_template = (@config['preferences'] && @config['preferences']['eval_erb']) ? :template : :copy_file
        Dir['scripts/*'].each {|file| send copy_or_template, File.expand_path(file), "compiled/scripts/#{File.basename(file)}" }
        Dir['roles/*'].each   {|file| send copy_or_template, File.expand_path(file), "compiled/roles/#{File.basename(file)}" }
        Dir['files/*'].each   {|file| send copy_or_template, File.expand_path(file), "compiled/files/#{File.basename(file)}" }
        (@config['files'] || []).each {|file| send copy_or_template, File.expand_path(file), "compiled/files/#{File.basename(file)}" }
        send copy_or_template, File.expand_path('roll.sh'), 'compiled/roll.sh'
        send copy_or_template, File.expand_path('config.sh'), 'compiled/config.sh'

        # Build install.sh
        if role
          if copy_or_template == :template
            template File.expand_path('install.sh'), 'compiled/_install.sh'
            create_file 'compiled/install.sh', File.binread('compiled/_install.sh') << "\n" << File.binread("compiled/roles/#{role}.sh")
          else
            create_file 'compiled/install.sh', File.binread('install.sh') << "\n" << File.binread("roles/#{role}.sh")
          end
        else
          send copy_or_template, File.expand_path('install.sh'), 'compiled/install.sh'
        end
      end

      def get_config()
        # Check if you're in the roll directory
        abort_with 'You must be in the roll folder' unless File.exists?('roll.yml')

        # Load roll.yml
        @config = YAML.load(File.read('roll.yml'))
      end

      def hosts(input)
        hosts = nil
        if !@config || !@config.has_key?('clusters') then
          return {input => input}
        end
        @config['clusters'].each {|key,value|
          if key == input then
            hosts=value
            break
          end
          if value.is_a? Hash
            value.each {|key, value|
              if key == input then
                hosts={key => value}
                break
              end
            }
          end
        }
        return hosts == nil ? {input => input} : hosts
      end

      def parse_target(target)
        target.match(/(.*@)?(.*?)(:.*)?$/)
        [ ($1 && $1.delete('@') || 'root'), $2, ($3 && $3.delete(':') || '22') ]
      end
    end
  end
end
