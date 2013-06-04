require 'thor'
require 'rainbow'
require 'yaml'

module Roll
  autoload :Cli,        'roll/cli'
  autoload :Cloud,      'roll/cloud'
  autoload :Dependency, 'roll/dependency'
  autoload :DNS,        'roll/dns'
  autoload :Logger,     'roll/logger'
  autoload :Utility,    'roll/utility'

  class Cloud
    autoload :Base,         'roll/cloud/base'
    autoload :Linode,       'roll/cloud/linode'
    autoload :DigitalOcean, 'roll/cloud/digital_ocean'
  end

  class DNS
    autoload :Base,     'roll/dns/base'
    autoload :Linode,   'roll/dns/linode'
    autoload :Route53,  'roll/dns/route53'
  end
end
