Puppet::Type.type(:jail_template).provide(:libiocage) do
  desc 'Manage creating of jails templates using ioc(8)'
  confine    kernel: :freebsd
  defaultfor kernel: :freebsd

  # this is used for further confinement
  commands ioc: '/usr/local/bin/ioc'

  def self.ioc(*args)
    cmd = ['/usr/local/bin/ioc', args].flatten.join(' ')
    execute(cmd, override_locale: false, failonfail: true, combine: true)
  end

  def ioc(*args)
    self.class.ioc(args)
  end

  def self.get_ioc_json_array(arg)
    return nil if arg == '-'
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
    templates = JSON.load(ioc('list', '--template', '--output-format=json', '--output=name,release,pkglist,postscript'))
    templates.map do |r|

      pkglist = get_ioc_json_array(r['pkglist'])
      postscript = get_ioc_json_array(r['postscript'])

      new(
        name: r['name'],
        ensure: :present,
        release: r['release'],
        pkglist: pkglist,
        postscript: postscript,
      )
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    ioc('create', '--release', resource[:release], '--name', resource[:name])
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
  end
end
