set name axis_ascon_aead128
set version "v1_0"

set dst "${name}_${version}"

create_project $name ../ip_repo/$dst -force

import_files -norecurse -fileset [get_filesets sources_1] [glob ../rtl/*.v]

set_property top $name [current_fileset]

ipx::package_project -root_dir ../ip_repo/$dst -vendor tristan.itschnerr -library cipher -taxonomy /cipher

set_property name $dst [ipx::current_core]
set_property vendor_display_name {Tristan Itschner} [ipx::current_core]
ipx::save_core [ipx::current_core]

ipx::update_checksums [ipx::current_core]
ipx::save_core [ipx::current_core]
