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
                               '--output=name,release,rlimits,user.pkglist'))
    templates.map do |r|
      pkglist = get_ioc_json_array(r['user.pkglist'])

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
        rlimits: rlimits.to_h,
        fstabs: fstabs,
        props: props.to_h,
      )
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def create
    ioc('create', '--release', resource[:release], '--name', resource[:name])
    if resource[:pkglist]
      ioc('pkg', resource[:name], resource[:pkglist].join(' '))
      ioc('set', 'user.pkglist="' + resource[:pkglist].join(',') + '"', resource[:name])
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

  def fstabs=(value)
    @property_flush[:fstabs] = value
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
    @property_hash[:ensure] = :absent
  end

  def flush
    # the only way to update release is to recreate
    if @property_flush[:release]
      destroy
      create
    end

    if @property_flush[:pkglist]
      desired_pkglist = Array((resource[:pkglist] == :absent) ? [] : resource[:pkglist])
      current_pkglist = Array((pkglist == :absent) ? [] : pkglist)
      remove_pkgs = (current_pkglist - desired_pkglist)
      ioc('pkg', '--remove', resource[:name], remove_pkgs.join(' ')) if remove_pkgs

      install_pkgs = (desired_pkglist - current_pkglist)
      ioc('pkg', resource[:name], install_pkgs.join(' ')) if install_pkgs

      ioc('set', 'user.pkglist="' + desired_pkglist.join(',') + '"', resource[:name])
    end

    if @property_flush[:fstabs]
      desired_fstabs = Array((resource[:fstabs] == :absent) ? [] : resource[:fstabs])
      current_fstabs = Array((fstabs == :absent) ? [] : fstabs)
      (current_fstabs - desired_fstabs).each do |f|
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'rm', rw, f[:src], resource[:name])
      end

      (desired_fstabs - current_fstabs).each do |f|
        rw = nil
        rw = '-rw' if ['true', :true, true].include? f[:rw]
        ioc('fstab', 'add', rw, f[:src], f[:dst], resource[:name])
      end
    end
    @property_flush = resource.to_hash
  end
end
