if Facter.value(:os) && Facter.value(:os)['release'] && Facter.value(:os)['release']['full']
  Facter.add(:freebsd_release) do
    confine kernel: :freebsd
    setcode do
      Facter.value(:os)['release']['full'].gsub(%r{-p\d+$}, '')
    end
  end
end
