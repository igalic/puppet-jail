Puppet::Type.type(:jail_template).provide(:libiocage) do
  desc 'Manage creating of jails templates using ioc(8)'
  confine    kernel: :freebsd
  defaultfor kernel: :freebsd

  # this is used for further confinement
  commands ioc: '/usr/local/bin/ioc'

  def self.ioc(*args)
    cmd = ['/usr/local/bin/ioc', args].flatten.compact.join(' ')
    execute(cmd, override_locale: false, failonfail: true, combine: true)
  end

  def ioc(*args)
    self.class.ioc(args)
  end

  def self.get_ioc_json_array(arg)
    return nil if arg == '-' || arg == ''
    return nil if arg.nil?
    return arg if arg.is_a?(Array)
    return arg.split(',') if arg.is_a?(String)
    raise("Unexpected Type for 'arg'")
  end

  def get_ioc_json_array(arg)
    self.class.get_ioc_json_array(arg)
  end

  mk_resource_methods

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def self.instances
    templates = JSON.parse(ioc('list', '--template', '--output-format=json', '--output=name,release,pkglist,postscript'))
    templates.map do |r|
      pkglist = get_ioc_json_array(r['pkglist'])
      postscript = get_ioc_json_array(r['postscript'])

      new(
        name: r['name'],
        ensure: :present,
        release: r['release'],
        pkglist: pkglist,
        postscript: postscript
      )
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    ip4_addr = ip6_addr = nil
    ip4_addr = "ip4_addr='#{resource[:ip4_addr]}'" if resource[:ip4_addr]
    ip6_addr = "ip6_addr='#{resource[:ip6_addr]}'" if resource[:ip6_addr]

    ioc('create', '--release', resource[:release], '--name', resource[:name], ip4_addr, ip6_addr)
    if resource[:pkglist] || resource[:postscript]
      # we'll need to start the jail for this to work
      ioc('start', resource[:name])

      if resource[:pkglist]
        ioc('exec', resource[:name], 'env', 'ASSUME_ALWAYS_YES=YES', 'pkg', 'bootstrap')
        ioc('exec', resource[:name], 'pkg', 'install', '-y', resource[:pkglist].join(' '))
        ioc('set', 'pkglist=' + resource[:pkglist].join(','), resource[:name])
      end

      if resource[:postscript]
        ioc('exec', resource[:name], resource[:postscript].join(';'))
        ioc('set', 'postscript=' + resource[:postscript].join(','), resource[:name])
      end

      ioc('set', 'ip4_addr=', 'ip6_addr=', resource[:name])
      ioc('stop', resource[:name])
    end
    # the last action is to set template=yes
    ioc('set', 'template=yes', resource[:name])
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
  end

  def flush
    destroy
    create
  end
end
