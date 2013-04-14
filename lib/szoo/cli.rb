require 'open3'
require 'ostruct'

module SZoo
  class Cli < Thor
    include Thor::Actions

    desc 'create', 'Create szoo project'
    def create(project = 'szoo')
      do_create(project)
    end

    desc 'deploy [user@host:port] [role] [--sudo]', 'Deploy szoo project'
    method_options :sudo => false
    def deploy(target, role = nil)
      do_deploy(target, role, options.sudo?)
    end

    desc 'compile', 'Compile szoo project'
    def compile(role = nil)
      do_compile(role)
    end

    desc 'setup [linode|digital_ocean]', 'Setup a new VM'
    def setup(provider)
      SZoo::Cloud.new(self, provider).setup
    end

    desc 'teardown [linode|digital_ocean] [name]', 'Teardown an existing VM'
    def teardown(provider, name)
      SZoo::Cloud.new(self, provider).teardown(name)
    end

    desc 'version', 'Show version'
    def version
      puts Gem.loaded_specs['szoo'].version.to_s
    end

    no_tasks do
      include SZoo::Utility

      def self.source_root
        File.expand_path('../../',__FILE__)
      end

      def do_create(project)
        copy_file 'templates/create/.gitignore',         "#{project}/.gitignore"
        copy_file 'templates/create/szoo.yml',           "#{project}/szoo.yml"
        copy_file 'templates/create/install.sh',         "#{project}/install.sh"
        copy_file 'templates/create/szoo.sh',            "#{project}/szoo.sh"
        copy_file 'templates/create/config.sh',          "#{project}/config.sh"
        copy_file 'templates/create/scripts/update.sh',  "#{project}/scripts/update.sh"
        copy_file 'templates/create/roles/db.sh',        "#{project}/roles/db.sh"
        copy_file 'templates/create/roles/web.sh',       "#{project}/roles/web.sh"
        copy_file 'templates/create/files/.gitkeep',     "#{project}/files/.gitkeep"
      end

      def do_deploy(target, role, force_sudo)
        sudo = 'sudo ' if force_sudo
        user, host, port = parse_target(target)
        endpoint = "#{user}@#{host}"

        # compile attributes and scripts
        do_compile(role)

        # The host key might change when we instantiate a new VM, so
        # we remove (-R) the old host key from known_hosts.
        `ssh-keygen -R #{host} 2> /dev/null`

        remote_commands = <<-EOS
        rm -rf ~/szoo &&
        mkdir ~/szoo &&
        cd ~/szoo &&
        tar xz &&
        #{sudo}bash install.sh
        EOS

        remote_commands.strip! << ' && rm -rf ~/szoo' if @config['preferences'] and @config['preferences']['erase_remote_folder']

        local_commands = <<-EOS
        cd compiled
        tar cz . | ssh -o 'StrictHostKeyChecking no' #{endpoint} -p #{port} '#{remote_commands}'
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

      def do_compile(role)
        # Check if you're in the szoo directory
        abort_with 'You must be in the szoo folder' unless File.exists?('szoo.yml')
        # Check if role exists
        abort_with "#{role} doesn't exist!" if role and !File.exists?("roles/#{role}.sh")

        # Load szoo.yml
        @config = YAML.load(File.read('szoo.yml'))

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

      def parse_target(target)
        target.match(/(.*@)?(.*?)(:.*)?$/)
        [ ($1 && $1.delete('@') || 'root'), $2, ($3 && $3.delete(':') || '22') ]
      end
    end
  end
end
