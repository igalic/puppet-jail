require 'puppetx/zleslie/helper'

Puppet::Type.type(:jail_release).provide(:libiocage) do
  desc 'Manage jails release base downloads using ioc(8)'
  confine    kernel: :freebsd
  defaultfor kernel: :freebsd

  # this is used for further confinement
  commands _ioc: '/usr/local/bin/ioc'

  mk_resource_methods

  extend PuppetX::Zleslie::Helper
  include PuppetX::Zleslie::Helper

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def self.instances
    releases = JSON.load(ioc('list', '--release', '--output-format=json'))
    releases.map { |r| new(name: r['name'], ensure: :present) }
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    ioc('fetch', '--release', resource[:name])
  end

  def destroy
    ioc('destroy', '--force', '--release', resource[:name])
  end
end
