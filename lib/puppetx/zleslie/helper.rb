# we have a lot of shared code
module PuppetX; end
module PuppetX::Zleslie; end

module PuppetX::Zleslie::Helper
  def self.ioc(*args)
    cmd = ['/usr/local/bin/ioc', args].flatten.compact.join(' ')
    Puppet::Util::Execution.execute(cmd, override_locale: false, failonfail: true, combine: true)
  end

  def ioc(*args)
    self.class.ioc(args)
  end

  def self.get_ioc_json_array(arg)
    return nil if arg == '-'
    return nil if arg == ''
    return nil if arg.nil?
    return arg if arg.is_a?(Array)
    return arg.split(',') if arg.is_a?(String)
    raise("Unexpected Type for 'arg'")
  end

  def get_ioc_json_array(arg)
    self.class.get_ioc_json_array(arg)
  end
end
