# coding: utf-8
# This type is meant to facilitate the deployment of FreeBSD jails.
#

Puppet::Type.newtype(:jail) do
  ensurable

  newproperty(:jid) do
    desc <<-EOM
         The jail ID for running jails

         This is a read-only property.
    EOM
  end

  # for py3-iocage, this can be uuid & hostname
  newparam(:name, namevar: true) do
    desc 'The name (and hostname) of the jail'
    newvalues(%r{^[a-zA-Z0-9_-]+$})
  end

  newproperty(:boot) do
    desc 'Either yes or no'
    newvalues(:yes, :no)
  end

  newproperty(:state) do
    desc 'Either running or stopped'
    newvalues(:running, :stopped)
  end

  newproperty(:release) do
    desc <<-EOM
         FreeBSD release of this jail. `EMPTY` if this is a Linux jail.  `release` and `template` are mutually exclusive.

         Changes to this property will lead to destruction and rebuild of the jail.
    EOM

    validate do |value|
      raise "Release must be a string, not '#{value.class}'" unless value.is_a?(String)
    end

    # iocage list -l will report release *with* the -patch level, but iocage
    # fetch expects it *without* the patch level.
    #
    # this is how we deal with that:
    def insync?(is)
      should = @should.is_a?(Array) ? @should.first : @should
      is.start_with?(should)
    end
  end

  newproperty(:template) do
    desc <<-EOM
         Template jail to base this one off. `release` and `template` are mutually exclusive.

         Changes to this property will lead to destruction and rebuild of the jail.
    EOM
  end

  newproperty(:ip4_addr) do
    desc <<-EOM
         Interface|Address[,Interface|Address[...]]

         Changes to this property will cause a restart of the jail.
    EOM
  end

  newproperty(:ip6_addr) do
    desc <<-EOM
         Interface|Address[,Interface|Address[...]]

         Changes to this property will cause a restart of the jail.
    EOM
  end

  newproperty(:fstabs, array_matching: :all) do
    desc <<-EOM
        An array of Hashes of directories to mount' of properties for this jail

        `src` is the path on the host. the optional `dst` is the destination
        in the container. `rw` defaults to `false`. Switch this to `true` to
        allow container processes to write to this mount point.

        Example:
        [
          { src => '/srv/www'},
          { src => '/data/containers/db/zoom', dst => '/var/lib/pg/dbs/zoom', rw => true}
          { src => '/data/containers/webdanger/bar', dst => '/srv/www/danger' },
        ]
      EOM
    # i thought we want to care about order here, but ioc doesn't ¯\(°_o)/¯
    def insync?(is)
      is = [] if !is || is == :absent
      is.flatten.sort == should.flatten.sort
    end
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
      is.flatten.sort == should.flatten.sort
    end
  end

  newproperty(:depends) do
    desc <<-EOM
      which (if any) jail this jail depends on

      Note that unlike ioc itself, we cannot create any dependencies on anything
      other than the jail name in puppet, so please only use the name!
    EOM
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

    munge do |v|
      v.each do |k, data|
        data['amount'] = data['amount'].to_s
        { k => data }
      end
    end
  end

  def refresh
    if self[:state] == :running
      provider.restart
    else
      debug 'Skipping restart: jail not running'
    end
  end

  validate do
    raise('Cannot supply both, template and release') if self[:template] && self[:release]
  end

  autorequire(:jail_release) do
    self[:release] if self[:release]
  end

  autorequire(:jail_template) do
    self[:template] if self[:template]
  end

  autorequire(:jail) do
    self[:depends] if self[:depends]
  end
end
