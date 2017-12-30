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
    jails = JSON.parse(ioc('list', '--output-format=json --output=name,release,from_template'))
    jails.map do |r|
      fstab = ioc('fstab', 'show', r['name'])
      fstabs = fstab.split("\n").map do |l|
        next if l =~ %r{^$|^#}
        src, dst, type, opts, _dump, _pass, trash = l.split(%r{\s+})
        raise ArgumentError, "this fstab line cannot be parsed.. in ruby: `#{l}`" unless trash.nil?
        rw = !(opts =~ %r{\brw\b}).nil?

        fs = { src: src, dst: dst, type: type, rw: rw }
        # apparently, munge is not ran after self.instances,
        # so we have to do repeat this:
        fs.delete(:type) if fs[:type] == 'nullfs'
        fs.delete(:dst) if fs[:dst] =~ %r{#{fs[:src]}$}
        fs.delete(:rw) if [:false, 'false', false].include? fs[:rw]
        fs
      end.compact

      new(
        ensure: :present,
        name: r['name'],
        release: r['release'],
        fstab: fstabs
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
    ioc('set', 'ip4_addr=', 'ip6_addr=', resource[:name])
    ioc('stop', resource[:name])
  end

  def release=(value)
    @property_flush[:release] = value
  end

  def fstab=(value)
    @property_flush[:fstab] = value
  end

  def destroy
    ioc('destroy', '--force', resource[:name])
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
