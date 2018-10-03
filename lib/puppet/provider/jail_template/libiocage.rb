# coding: utf-8

require 'puppetx/zleslie/helper'

Puppet::Type.type(:jail_template).provide(:libiocage) do
  desc 'Manage creating of jails templates using ioc(8)'
  confine    kernel: :freebsd
  defaultfor kernel: :freebsd

  # this is used for further confinement
  commands _ioc: '/usr/local/bin/ioc'

  mk_resource_methods

  extend PuppetX::Zleslie::Helper
  include PuppetX::Zleslie::Helper

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
    default_props, default_rlimits = get_all_props('defaults')

    templates = JSON.parse(ioc('list', '--template', '--output-format=json',
                               '--output=name,release,ip4_addr,ip6_addr,rlimits,user.pkglist,user.postscript'))
    templates.map do |r|
      pkglist = get_ioc_json_array(r['user.pkglist'])
      postscript = get_ioc_json_array(r['user.postscript'])

      fstabs = get_fstabs(r['name'])

      props, rlimits = get_all_props(r['name'])
      props -= default_props
      props -= { # these are defaults which are… different
        'basejail' => 'yes',
        'host_domainname' => 'local',
        'host_hostname' => r['name'],
        'host_hostuuid' => r['name'],
      }
      rlimits -= default_rlimits

      new(
        name: r['name'],
        ensure: :present,
        release: r['release'],
        pkglist: pkglist,
        postscript: postscript,
        ip4_addr: get_ioc_json_string(r['ip4_addr']),
        ip6_addr: get_ioc_json_string(r['ip6_addr']),
        rlimits: rlimits.to_h,
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

    ioc('create', '--release', resource[:release], '--name', resource[:name], ip4_addr, ip6_addr)
    if resource[:pkglist] || resource[:postscript]
      # we'll need to start the jail for this to work
      ioc('start', resource[:name])

      if resource[:pkglist]
        ioc('exec', resource[:name], 'env ASSUME_ALWAYS_YES=YES pkg bootstrap')
        ioc('exec', resource[:name], 'pkg install -y', resource[:pkglist].join(' '))
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
    @property_hash = @property_flush
  end

  def pkglist=(value)
    @property_flush[:pkglist] = value
  end

  def postprovision=(value)
    @property_flush[:postprovision] = value
  end

  def release=(value)
    @property_flush[:release] = value
  end

  def fstab=(value)
    @property_flush[:fstab] = value
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
    @property_hash[:ensure] = :absent
  end

  def flush
    # the only way to update release, pkglist, or postscript is to recreate
    if @property_flush[:release] || @property_flush[:pkglist] || @property_flush[:postscript]
      destroy
      create
    end

    if @property_flush[:fstab]
      desired_fstab = Array((resource[:fstab] == :absent) ? [] : resource[:fstab])
      current_fstab = Array((fstab == :absent) ? [] : fstab)
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
