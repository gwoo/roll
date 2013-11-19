Roll
====

A fork of [Sunzi](https://github.com/kenn/sunzi)

```
"The supreme art of war is to subdue the enemy without fighting." - Sunzi
```

Roll, like Sunzi is an easy [server provisioning](http://en.wikipedia.org/wiki/Provisioning#Server_provisioning) utility designed with simplicity in mind. If Chef or Puppet is driving you nuts, try Roll!


Its design goals are:

* **It's just shell script.** No clunky Ruby DSL involved. Most of the information about server configuration on the web is written in shell commands. Just copy-paste them, rather than translate it into an arbitrary DSL. Also, Bash is the greatest common denominator on minimum Linux installs.
* **Focus on diff from default.** No big-bang overwriting. Append or replace the smallest possible piece of data in a config file. Loads of custom configurations make it difficult to understand what you are really doing.
* **Always use the root user.** Think twice before blindly assuming you need a regular user - it doesn't add any security benefit for server provisioning, it just adds extra verbosity for nothing. However, it doesn't mean that you shouldn't create regular users with Roll - feel free to write your own scripts.
* **Minimum dependencies.** No configuration server required. You don't even need a Ruby runtime on the remote server.


Quickstart
----------

Install:

```bash
$ git clone https://github.com/gwoo/roll
$ cd roll && rake install
$ roll version
```

Go into your project directory (if it's a Rails project, `config` would be a good place to start with), then:

```bash
$ roll create
```

It generates a `roll` folder along with subdirectories and templates. Inside `roll`, there are `roll.yml` and `install.sh`. Those two are the most important files that you mainly work on.

Go into the `roll` directory, then run `roll deploy`:

```bash
$ cd roll
$ roll deploy <host>
```

Now, what it actually does is:

1. Compile `roll.yml` to generate attributes and retrieve remote scripts, then copy files into the `compiled` directory
1. SSH to `<host>` and login as `root`
1. Transfer the content of the `compiled` directory to the remote server and extract in `$HOME/roll`
1. Add `ROLL_NAME`, `ROLL_HOST`, `ROLL_USER` to config.sh
1. Run `install.sh` on the remote server

As you can see, all you need to do is edit `install.sh` and add some shell commands. That's it.

A Roll project without any scripts or roles is totally fine, so that you can start small, go big as you get along.

Commands
--------

```bash
$ roll                                           # Show command help
$ roll compile                                   # Compile Roll project
$ roll create                                    # Create a new Roll project
$ roll deploy [cluster|user@host:port] [role] [--sudo]   # Deploy Roll project

$ roll setup [linode|digital_ocean]              # Setup a new VM on the cloud services
$ roll teardown [linode|digital_ocean] [name]    # Teardown an existing VM on the cloud services
```

Directory structure
-------------------

Here's the directory structure that `roll create` automatically generates:

```bash
roll/
  install.sh      # main script
  roll.yml        # add custom attributes and remote scripts here

  scripts/        # put commonly used scripts here, referred from install.sh
    roll.sh
  roles/          # when role is specified, scripts here will be concatenated
    db.sh         # to install.sh in the compile phase
    web.sh
  files/          # put any files to be transferred
  compiled/       # everything under this folder will be transferred to the
                  # remote server (do not edit directly)
```

How do you pass dynamic values?
-------------------------------

Roll adds `ROLL_NAME`, `ROLL_HOST`, `ROLL_USER` to config.sh at runtime,
so you can access `$ROLL_NAME`, `$ROLL_HOST`, `$ROLL_USER` in your scripts

Also, There are two ways to pass dynamic values to the script - ruby and bash.

**For ruby (recommended)**: Make sure `eval_erb: true` is set in `roll.yml`. In the compile phase, attributes defined in `roll.yml` are accessible from any files in the form of `<%= @attributes.ruby_version %>`.

**For bash**: In the compile phase, attributes defined in `roll.yml` are split into multiple files in `compiled/attributes`, one per attribute. Now you can refer to it by `$(cat attributes/ruby_version)` in the script.

For instance, given the following `install.sh`:

```bash
echo "Goodbye <%= @attributes.goodbye %>, Hello <%= @attributes.hello %>!"
```

With `roll.yml`:

```yaml
attributes:
  goodbye: Chef
  hello: Roll
```

Now, you get the following result.

```
Goodbye Chef, Hello Roll!
```

Remote Scripts
--------------

Scripts can be retrieved remotely via HTTP. Put a URL in the scripts section of `roll.yml`, and Roll will automatically load the content and put it into the `compiled/scripts` folder in the compile phase.

For instance, if you have the following line in `roll.yml`,

```yaml
scripts:
  rvm: https://raw.github.com/gwoo/roll-scripts/master/nginx.sh
```

`rvm.sh` will be available and you can refer to that recipe by `source scripts/rvm.sh`.

You may find sample scripts in these repositories useful:
  - https://github.com/gwoo/roll-scripts
  - https://github.com/kenn/sunzi-recipes


Role-based configuration
------------------------

You probably have different configurations between **web servers** and **database servers**.

No problem - how Roll handles role-based configuration is refreshingly simple.

Shell scripts under the `roles` directory, such as `web.sh` or `db.sh`, are automatically recognized as a role. The role script will be appended to `install.sh` at deploy, so you should put common configurations in `install.sh` and role specific procedures in the role script.

For instance, when you set up a new web server, deploy with a role name:

```bash
roll deploy <cluster|host> web
```

It is equivalent to running `install.sh`, followed by `web.sh`.

Examples
--------
You can find a sample or two here: https://github.com/gwoo/roll-apps


Cloud Support
-------------

You can setup a new VM, or teardown an existing VM interactively. Use `roll setup` and `roll teardown` for that.

#### Compute
 - [Linode](http://www.linode.com/)
 - [DigitalOcean](https://www.digitalocean.com)

### DNS
  - [Linode](http://www.linode.com/)
  - [Amazon Route 53](http://aws.amazon.com/route53/)

Vagrant
-------

If you're using Roll with [Vagrant](http://vagrantup.com/), make sure that you have a root access via SSH.

An easy way is to edit `Vagrantfile`:

```ruby
Vagrant::Config.run do |config|
  config.vm.provision :shell, :inline => "echo 'root:vagrant' | /usr/sbin/chpasswd"
end
```

and now run `vagrant up`, it will change the root password to `vagrant`.

Also keep in mind that you need to specify the port number 2222.

```bash
$ roll deploy <host>:2222
```


What's new
----------

* v1.4: Added `ROLL_NAME`, `ROLL_HOST`, `ROLL_USER` dynamic update.
* v1.3: Added clusters to roll.yml
* v1.2: Evaluate everything as ERB templates by default. Added "files" folder.
* v1.1: "set -e" by default. apt-get everywhere in place of aptitude. Linode DNS support for DigitalOcean instances.
* v1.0: System functions are refactored into roll.mute() and roll.install().
* v0.9: Support for [DigitalOcean](https://www.digitalocean.com) setup / teardown.
* v0.8: Added `--sudo` option to `roll deploy`.
* v0.7: Added `erase_remote_folder` and `cache_remote_scripts` preferences for customized behavior.
* v0.6: System function roll::silencer() added for succinct log messages.
* v0.5: Role-based configuration supported. Reworked directory structure. **Incompatible with previous versions**.


What's todo
-----------
 - support more clouds
 - support image creation
 - support running arbitrary commands with logging