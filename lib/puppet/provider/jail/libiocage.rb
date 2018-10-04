# coding: utf-8

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
    default_props, default_rlimits = get_all_props('defaults')

    jails = JSON.parse(
      ioc('list', '--output-format=json',
          '--output=name,boot,running,release,ip4_addr,ip6_addr,rlimits,user.template,user.pkglist'),
    )
    jail_klass = struct_from_hash('JailStruct', jails[0])
    jails.map do |r|
      s = hash2struct(jail_klass, r)
      r = nil

      pkglist = get_ioc_json_array(s['user.pkglist'])

      fstabs = get_fstabs(s['name'])

      state = :stopped
      state = :running if s['running'] == 'yes'

      props, rlimits = get_all_props(s['name'])
      props -= default_props
      props -= { # these are defaults which are… different
        'basejail' => 'yes',
        'host_domainname' => 'local',
        'host_hostname' => s['name'],
        'host_hostuuid' => s['name'],
      }

      rlimits -= default_rlimits

      new(
        ensure: :present,
        name: s['name'],
        release: s['release'],
        boot: s['boot'],
        template: get_ioc_json_string(s['user.template']),
        pkglist: pkglist,
        ip4_addr: get_ioc_json_string(s['ip4_addr']),
        ip6_addr: get_ioc_json_string(s['ip6_addr']),
        rlimits: rlimits.to_h,
        state: state,
        fstabs: fstabs,
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

    from = []
    if !resource[:release].nil? && resource[:release] != :absent
      from << "--release=#{resource[:release]}"
    end
    if !resource[:template].nil? && resource[:template] != :absent
      from << "--template=#{resource[:template]}"
      from << "user.template=#{resource[:template]}"
    end

    boot = nil if resource[:boot] == :off
    boot = 'boot=on' if resource[:boot] == :on

    props_arr = []
    if !resource[:props].nil? && resource[:props] != :absent
      resource[:props].each do |p, v|
        props_arr << "#{p}='#{v}'"
      end
    end

    ioc('create', resource[:name],
        *from, ip4_addr, ip6_addr, boot, *props_arr)

    if !resource[:pkglist].nil? && resource[:pkglist] != :absent
      pkglist = resource[:pkglist].flatten
      ioc('pkg', resource[:name], pkglist.join(' '))
      ioc('set', "user.pkglist='" + pkglist.join(',') + "'", resource[:name])
    end

    if !resource[:fstabs].nil? && resource[:fstabs] != :absent
      resource[:fstabs].each do |f|
        rw = nil
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'add', rw, f[:src], f[:dst], resource[:name])
      end
    end

    ioc('start', resource[:name]) if resource[:state] == :running

    resource[:ensure] = :present
  end

  def boot=(value)
    @property_flush[:boot] = value
  end

  def state=(value)
    action = 'start' if value.to_sym == :running
    action = 'stop' if value.to_sym == :stopped
    ioc(action, resource[:name])
    @property_hash[:state] = value
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

  def pkglist=(value)
    value = [] if value.nil?
    @property_flush[:pkglist] = value.flatten
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
    resource[:ensure] = :absent
  end

  def flush
    # the only way to update release or template, is to recreate
    if @property_flush[:release] || @property_flush[:template]
      destroy
      create
    end

    if @property_flush[:pkglist]
      remove_pkgs, install_pkgs = array_diff(resource[:pkglist], @property_flush[:pkglist])

      ioc('pkg', '--remove', resource[:name], remove_pkgs.join(' ')) unless remove_pkgs.empty?
      ioc('pkg', resource[:name], install_pkgs.join(' ')) unless install_pkgs.empty?

      ioc('set', 'user.pkglist="' + @property_flush[:pkglist].flatten.compact.join(',') + '"', resource[:name])
    end

    if @property_flush[:fstabs]
      remove_fstabs, add_fstabs = array_diff(resource[:fstabs], @property_flush[:fstabs])

      remove_fstabs.each do |f|
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'rm', rw, f[:src], resource[:name])
      end

      add_fstabs.each do |f|
        rw = nil
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'add', rw, f[:src], f[:dst], resource[:name])
      end
    end
    @property_hash = resource.to_hash
  end
end
