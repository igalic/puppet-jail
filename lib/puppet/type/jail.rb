# This type is meant to facilitate the deployment of FreeBSD jails.
#
# We make assumptions.
#
# 1. The directories that you are attempting to deploy a jail to, actually exists.
#

Puppet::Type.newtype(:jail) do
  newparam(:name, namevar: true) do
    desc 'The name of the jail, and only the name'
  end

  newproperty(:ensure) do
    desc 'Ensure jail present, absent, or template'
    newvalues(:present, :absent, :template)
  end

  newparam(:jid) do
    desc 'The jail ID for running jails'
  end

  newparam(:user_data) do
    desc 'Rendered content to pipe to a jailed shell upon creation'
  end

  newproperty(:state) do
    desc 'Either running or stopped'
    newvalues(:up, :down)
  end

  newproperty(:boot) do
    desc 'Either on or off'
    newvalues(:on, :off)
  end

  newproperty(:ip4_addr) do
    desc 'Interface|Address'
  end

  newproperty(:ip6_addr) do
    desc 'Interface|Address'
  end

  newproperty(:template) do
    desc 'Template to use'
  end
  newproperty(:release) do
    desc 'Release to use'
  end

  newproperty(:hostname) do
    desc 'Hostname of the jail'
  end

  newproperty(:jail_zfs) do
    desc 'Enable the jail_zfs'
    newvalues(:on, :off)
  end

  newproperty(:jail_zfs_dataset) do
    desc 'Set the jail_zfs_data set iocage parameter'
    validate do |value|
      unless value.is_a? String
        raise ArgumentError, 'jail_zfs_dataset requires string value'
      end
    end
  end

  newparam(:pkglist, array_matching: :all) do
    desc 'A list of packages to be installed in this jail before startup'
    def insync?(is)
      Array(is).sort == Array(@shouldA).sort
    end

    newvalues(%r{^}) do
      begin
        provider.update
      rescue => detail
        raise Puppet::Error, "Could not update: #{detail}"
      end
    end
  end

  newproperty(:type) do
    desc 'This read-only property describes the what type of jail this is'
    newvalues(:jail, :template, :basejail)
  end

  def refresh
    if @parameters[:state] == :up
      provider.restart
    else
      debug 'Skipping restart: jail not running'
    end
  end
end
