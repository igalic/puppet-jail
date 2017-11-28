# This type is meant to facilitate the deployment of FreeBSD jails by helping
# create templates
Puppet::Type.newtype(:jail_template) do
  @doc = <<-'EOT'
    This type is meant to facilitate the deployment of FreeBSD jails by helping
    create templates.

    It does so using a mix of `pkglist` and `postscript`. Both parameters will
    be stored in the template's configuration, so it can be (re)discovered
    through `puppet resource jail_template`.

    Note that this is a crutch until `ioc` supports `provisioning`.
  EOT
  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the template'
  end

  newproperty(:release) do
    desc 'The release this template is built upon'
  end

  newproperty(:pkglist, array_matching: :all) do
    desc "A list of packages to be installed"
  end

  newproperty(:postscript, array_matching: :all) do
    desc "A script (one line per entry) to execute after (optionally) installing packages."
  end

  def self.validate_ip(ip)
    return true if ip.nil?

    netif, ip_addr = ip.split('|')
    return false if netif.nil?
    return false if ip_addr.nil?

    _ = IPAddr.new(ip_addr)
    return true
  rescue IPAddr::InvalidAddressError
    return false
  end

  newparam(:ip4_addr) do
    desc "ip4_addr only used for installing packages"
    validate do |ip|
      validate_ip(ip)
    end
  end

  newparam(:ip6_addr) do
    desc "ip6_addr only used for installing packages"
    validate do |ip|
      validate_ip(ip)
    end
  end

  validate do
    if self[:pkglist] && !(self[:ip4_addr] || self[:ip6_addr])
      raise ArgumentError, "a Network setup is required for installing packages. Please set ip4_addr or ip6_addr!"
    end
  end
end
