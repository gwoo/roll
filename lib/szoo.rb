require 'thor'
require 'rainbow'
require 'yaml'

module SZoo
  autoload :Cli,        'szoo/cli'
  autoload :Cloud,      'szoo/cloud'
  autoload :Dependency, 'szoo/dependency'
  autoload :DNS,        'szoo/dns'
  autoload :Logger,     'szoo/logger'
  autoload :Utility,    'szoo/utility'

  class Cloud
    autoload :Base,         'szoo/cloud/base'
    autoload :Linode,       'szoo/cloud/linode'
    autoload :DigitalOcean, 'szoo/cloud/digital_ocean'
  end

  class DNS
    autoload :Base,     'szoo/dns/base'
    autoload :Linode,   'szoo/dns/linode'
    autoload :Route53,  'szoo/dns/route53'
  end
end
