# This type is meant to facilitate the deployment of FreeBSD jails by helping
# create templates
Puppet::Type.newtype(:jail_template) do
  @doc = "This type is meant to facilitate the deployment of FreeBSD jails by helping create templates"
  ensurable

  newparam(:name, namevar: true) do
    desc 'The name of the template'
  end

  newproperty(:release) do
    desc 'The release this template is built upon'
  end

  newparam(:provision_script, array_matching: :all) do
    desc "A script (one line per entry) to execute upon provisioning. This will run after packages, if any, are installed."
  end

  newparam(:pkglist, array_matching: :all) do
    desc "A list of packages to be installed"
  end
end
