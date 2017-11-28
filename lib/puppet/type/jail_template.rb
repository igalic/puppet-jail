# This type is meant to facilitate the deployment of FreeBSD jails by helping
# create templates
Puppet::Type.newtype(:jail_template) do
  @doc = <<-'EOT'
    This type is meant to facilitate the deployment of FreeBSD jails by helping
    create templates.

    It does so using a mix of `pkglist` and `postscript`. Both parameters will
    be stored in the template's configuration, so it can be (re)discovered
    through `puppet resource jail_template`.

    Note that this is a crutch until `ioc` supports `provisioning`.
  EOT
  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the template'
  end

  newproperty(:release) do
    desc 'The release this template is built upon'
  end

  newproperty(:pkglist, array_matching: :all) do
    desc "A list of packages to be installed"
  end

  newproperty(:postscript, array_matching: :all) do
    desc "A script (one line per entry) to execute after (optionally) installing packages."
  end

end
