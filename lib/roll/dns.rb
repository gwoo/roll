module Roll
  class DNS
    def initialize(config, cloud)
      dns = config['dns']
      @subject = case dns
      when 'linode'
        Roll::DNS::Linode.new(config, cloud)
      when 'route53'
        Roll::DNS::Route53.new(config, cloud)
      else
        abort_with "DNS #{dns} is not valid!"
      end
    end

    def method_missing(sym, *args, &block)
      @subject.send sym, *args, &block
    end
  end
end
