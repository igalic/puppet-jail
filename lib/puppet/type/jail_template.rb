# This type is meant to facilitate the deployment of FreeBSD jails by helping
# create templates
Puppet::Type.newtype(:jail_template) do
  @doc = <<-EOT
    This type is meant to facilitate the deployment of FreeBSD jails by helping
    create templates.

    It does so using a mix of `pkglist`. This parameters will
    be stored in the template's configuration, so it can be (re)discovered
    through `puppet resource jail_template`.
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

    munge do |x|
        x.split(',') if x.is_a?(String)
    end

    # overridden so that we match with self.should
    def insync?(is)
      is = [] if !is || is == :absent
      is.sort == should.sort
    end
  end

  newproperty(:fstabs, array_matching: :all) do
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
      wrong = fs.keys - ['src', 'dst', 'type', 'rw']
      raise ArgumentError, "Invalid keys supplied for fstab: #{wrong}" unless wrong.empty?
    end

    # overridden so that we match with self.should
    def insync?(is)
      # order in these arrays is kinda important, and ruby's Hash.== compares
      # hashes structurally, so we should be set here:
      is == should
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

  autorequire(:jail_release) do
    self[:release]
  end
end
