# we have a lot of shared code
module PuppetX; end
module PuppetX::Zleslie; end

module PuppetX::Zleslie::Helper
  def ioc(*args)
    cmd = ['/usr/local/bin/ioc', args].flatten.compact.join(' ')
    Puppet::Util::Execution.execute(cmd, override_locale: false, failonfail: true, combine: true)
  end

  def get_ioc_json_array(arg)
    return nil if arg == '-'
    return nil if arg == 'None'
    return nil if arg == ''
    return nil if arg.nil?
    return arg if arg.is_a?(Array)
    return arg.split(',') if arg.is_a?(String)
    raise("Unexpected Type '#{arg.class}'. Expecting String or Array")
  end

  def get_ioc_json_string(arg)
    return nil if arg == '-'
    return nil if arg == 'None'
    return nil if arg == ''
    return nil if arg.nil?
    return arg if arg.is_a?(String)
    raise("Unexpected Type: '#{arg.class}'. Expecting String.")
  end

  def get_fstab(jail_name)
      fstab = ioc('fstab', 'show', jail_name)
      fstabs = fstab.split("\n").map do |l|
        next if l =~ %r{^$|^#}
        src, dst, type, opts, _dump, _pass, trash = l.split(%r{\s+})
        raise ArgumentError, "this fstab line cannot be parsed.. in ruby: `#{l}`" unless trash.nil?
        rw = !(opts =~ %r{\brw\b}).nil?

        fs = { src: src, dst: dst, type: type, rw: rw }
        # apparently, munge is not ran after self.instances,
        # so we have to do repeat this:
        fs.delete(:type) if fs[:type] == "nullfs"
        fs.delete(:dst) if fs[:dst] =~ %r{#{fs[:src]}$}
        fs.delete(:rw) if [:false, "false", false].include? fs[:rw]
        fs
      end.compact
      fstabs
    end

  def get_all_props(jail_name="defaults")
    props = ioc('get', 'all', jail_name).split("\n").map do |p|
      [k, v] = p.split(':', 2)
    end.to_h
    # delete all properties we already have as properties or parameters, or
    # which cannot be possibly equal
    props.delete("id")
    props.delete("ip4_addr")
    props.delete("ip6_addr")
    props.delete("rlimits")
    props.delete("release")
    props.delete("user.pkglist")
    props.delete("user.postscript")
    props.delete("user.template")
    props
end
