# we have a lot of shared code
module PuppetX; end
module PuppetX::Zleslie; end

module PuppetX::Zleslie::Helper
  def ioc(*args)
    cmd = ['/usr/local/bin/ioc', args].flatten.compact.join(' ')
    Puppet::Util::Execution.execute(cmd, override_locale: false, failonfail: true, combine: true)
  end

  def struct_from_hash(name, data)
    Kernel.const_get('Struct::' + name)
  rescue NameError
    keys = data.keys.map { |x| x.to_sym }
    Struct.new(name, *keys)
  end

  def hash2struct(klass, data)
    keys = data.keys.map { |x| x.to_sym }
    s = klass.new
    keys.each do |k|
      s[k.to_s] = data[k.to_s]
    end
    s
  end

  TYPE_PARAMS = [
    'boot',
    'id',
    'ip4_addr',
    'ip6_addr',
    'release',
    'rlimits',
    'running',
    'template',
    'user.pkglist',
    'user.template',
  ].freeze

  RCTL = [
    # env MANWIDTH=300 man rctl | grep -A25 '^R.*E.*S.*O' | tail -25 |\
    # awk  '{print "\'" $1 "\',"}'
    'cputime',
    'datasize',
    'stacksize',
    'coredumpsize',
    'memoryuse',
    'memorylocked',
    'maxproc',
    'openfiles',
    'vmemoryuse',
    'pseudoterminals',
    'swapuse',
    'nthr',
    'msgqqueued',
    'msgqsize',
    'nmsgq',
    'nsem',
    'nsemop',
    'nshm',
    'shmsize',
    'wallclock',
    'pcpu',
    'readbps',
    'writebps',
    'readiops',
    'writeiops',
  ].freeze

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

  def get_fstabs(jail_name)
    fstab = ioc('fstab', 'show', jail_name)
    fstabs = fstab.split("\n").map do |l|
      next if l =~ %r{^\s*$|^\s*#}
      next if l =~ %r{# iocage-auto\s*$}
      next if l =~ %r{root/.iocage-pkg}

      src, dst, type, opts, _dump, _pass, trash = l.split(%r{\s+})
      raise ArgumentError, "this fstab line cannot be parsed.. in ruby: `#{l}`" unless trash.nil?
      rw = !(opts =~ %r{\brw\b}).nil?

      fs = { src: src, dst: dst, type: type, rw: rw }
      # apparently, munge is not ran after self.instances,
      # so we have to do repeat this:
      fs.delete(:type) if fs[:type] == 'nullfs'
      fs.delete(:dst) if fs[:dst] =~ %r{#{fs[:src]}$}
      fs.delete(:rw) if [:false, 'false', false].include? fs[:rw]
      fs
    end
    fstabs.compact
  end

  def get_all_props(jail_name = 'defaults')
    props = ioc('get', 'all', jail_name).split("\n").map do |p|
      _k, _v = p.split(':', 2)
    end
    props = props.to_h
    # delete all properties we already have as properties or parameters, or
    # which cannot be possibly equal
    props.delete_if { |k, _v| TYPE_PARAMS.include? k }

    # "temporary" hack
    props['jail_zfs_dataset'] = '-' if props['jail_zfs_dataset'] == 'None'

    # put all rlimits into a different hash
    rlimits = {}
    props.delete_if do |k, v|
      if RCTL.include? k

        per = '/jail'
        action = amount = nil
        if !v.include?('=') && !v.include?(':')
          amount = v
          action = 'deny'
        elsif !v.include?('=')
          action, rest = v.split('=')
          amount, per = rest.split('/')
          per = '/jail' if per.nil?
        elsif !v.include?(':')
          amount, action = v.split('=')
        end
        rlimits[k] = { amount: amount, action: action, per: per }
        true
      else
        false
      end
    end

    [Set.new(props), Set.new(rlimits)]
  end

  def array_diff(is, should)
    # normalize should & is:
    desired = Array((should == :absent) ? [] : is.flatten.compact)
    current = Array((is == :absent) ? [] : is.flatten.compact)

    # calculate diffs:
    remove = (current - desired)
    add = (desired - current)

    [remove, add]
  end
end
