require 'puppetx/zleslie/helper'

Puppet::Type.type(:jail).provide(:libiocage) do
  desc 'Manage creating of jails using ioc(8)'
  confine    kernel: :freebsd
  defaultfor kernel: :freebsd

  # this is used for further confinement
  commands _ioc: '/usr/local/bin/ioc'

  extend PuppetX::Zleslie::Helper
  include PuppetX::Zleslie::Helper

  mk_resource_methods

  def initialize(value = {})
    super(value)
    @property_flush = {}
  end

  def self.prefetch(resources)
    instances.each do |prov|
      if (resource = resources[prov.name])
        resource.provider = prov
      end
    end
  end

  def self.instances
    default_props = get_all_props("defaults")

    jails = JSON.parse(ioc('list', '--output-format=json',
       '--output=name,release,ip4_addr,ip6_addr,rlimits,user.template'))
    jails.map do |r|
      fstabs = get_fstabs(r['name'])

      props = get_jail_properties(r['name'])
      props = props - default_props

      new(
        ensure: :present,
        name: r['name'],
        release: r['release'],
        template: get_ioc_json_string(r['user.template']),
        ip4_addr: get_ioc_json_string(r['ip4_addr']),
        ip6_addr: get_ioc_json_string(r['ip6_addr']),
        rlimits: get_ioc_json_string(r['rlimits']),
        fstab: fstabs,
        props: props.to_h,
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

    ioc('create', '--release', resource[:release], '--basejail', '--name',
      resource[:name], ip4_addr, ip6_addr)
    resource[:ensure] = :present
  end

  def release=(value)
    @property_flush[:release] = value
  end

  def template=(value)
    @property_flush[:template] = value
  end

  def fstab=(value)
    @property_flush[:fstab] = value
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
    resource[:ensure] = :absent
  end

  def flush
    # the only way to update release, pkglist, or postscript is to recreate
    if @property_flush[:release] || @property_flush[:pkglist] || @property_flush[:postscript]
      destroy
      create
    end

    if @property_flush[:fstab]
      desired_fstab = Array(resource[:fstab] == :absent ? [] : resource[:fstab])
      current_fstab = Array(fstab == :absent ? [] : fstab)
      (current_fstab - desired_fstab).each do |f|
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'rm', rw, f[:src], resource[:name])
      end

      (desired_fstab - current_fstab).each do |f|
        rw = nil
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'add', rw, f[:src], f[:dst], resource[:name])
      end
    end
    @property_flush = resource.to_hash
  end
end
