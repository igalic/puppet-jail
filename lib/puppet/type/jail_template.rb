# This type is meant to facilitate the deployment of FreeBSD jails by helping
# create templates
Puppet::Type.newtype(:jail_template) do
  @doc = <<-EOT
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
    desc 'A list of packages to be installed'

    attr_reader :should

    # overridden so that we match with self.should
    def insync?(is)
      is = [] if !is || is == :absent
      is.sort == should.sort
    end
  end

  newproperty(:postscript, array_matching: :all) do
    desc 'A script (one line per entry) to execute after (optionally) installing packages.'

    attr_reader :should

    # overridden so that we match with self.should
    def insync?(is)
      is = [] if !is || is == :absent
      is.sort == should.sort
    end
  end

  newproperty(:fstab, array_matching: :all) do
    desc <<-EOT
    An array of of Hashes describing the fstab entries of the jail.

    The Struct is of the type:
       { src: /path, [dst: /path], [rw: false]}.'

       dst is optional
       type is optional, currently only nullfs is supported
       rw is also optional, and defaults to false
    EOT

    attr_reader :should

    munge do |fs|
      # convert string to keys
      fs = Hash[fs.map { |k, v| [k.to_sym, v] }]
      # remove defaults
      fs.delete(:type) if fs[:type] == 'nullfs'
      fs.delete(:dst) if fs[:dst] =~ %r{#{fs[:src]}$}
      fs.delete(:rw) if [:false, 'false', false].include? fs[:rw]
      fs
    end

    validate do |fs|
      wrong = fs.keys - %w[src dst type rw]
      raise ArgumentError, "Invalid keys supplied for fstab: #{wrong}" unless wrong.empty?
    end

    # overridden so that we match with self.should
    def insync?(is)
      # order in these arrays is kinda important, and ruby's Hash.== compares
      # hashes structurally, so we should be set here:
      is == should
    end
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

  newproperty(:ip4_addr) do
    desc "ip4_addr only used for installing packages. The IPv4 Address or CIDR must be of the form: 'vtnet0|172.16.0.12/12'"
    validate do |ip|
      Puppet::Type::Jail_template.validate_ip(ip)
    end
  end

  newproperty(:ip6_addr) do
    desc "ip6_addr only used for installing packages. The IPv6 Address or CIDR must be of the form: 'vtnet0|2001:db8:a0b:12f0::1/64'"
    validate do |ip|
      Puppet::Type::Jail_template.validate_ip(ip)
    end
  end

  newproperty(:props) do
    desc 'A Hash of properties for this jail'
  end

  newproperty(:rlimits) do
    desc <<-EOM
      A Hash of rlimits for this jail

      Example:
        jail { xforkb:
           ensure => present,
          rlimits => { nproc => {action => deny, amount => 50}}
        }

      This creates a jail that makes it impossible to fork-bomb, since we
      will not allow to spawn more than 50 processes (nproc)
     EOM
  end

  validate do
    if self[:pkglist] && !(self[:ip4_addr] || self[:ip6_addr])
      raise ArgumentError, 'a Network setup is required for installing packages. Please set ip4_addr or ip6_addr!'
    end
  end

  autorequire(:jail_release) do
    self[:release]
  end
end
