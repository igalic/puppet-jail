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
    desc 'Either on or off'
    newvalues(:on, :off)
  end

  newproperty(:state) do
    desc 'Either running or stopped'
    newvalues(:up, :down)
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

  newproperty(:fstabs) do
    desc<<-EOM
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
  end

  newproperty(:props) do
    desc 'A Hash of properties for this jail'
  end

  newproperty(:rlimits) do
    desc<<-EOM
      A Hash of rlimits for this jail

      Please see rctl(8) for a complete documentation
     EOM
  end

  def refresh
    if @parameters[:state] == :up
      provider.restart
    else
      debug 'Skipping restart: jail not running'
    end
  end

  autorequire(:jail_release) do
    self[:release] if self[:release]
  end

  autorequire(:jail_template) do
    self[:template] if self[:template]
  end
end
