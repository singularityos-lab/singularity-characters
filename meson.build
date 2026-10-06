project('singularity-characters', ['vala', 'c'],
  version: '0.1.0',
  meson_version: '>= 0.59.0'
)

i18n = import('i18n')
add_project_arguments('-DGETTEXT_PACKAGE="singularity-characters"', language: 'c')
subdir('po')

gnome = import('gnome')

gtk_dep = dependency('gtk4')
gee_dep = dependency('gee-0.8')

libsingularity_dep = dependency('singularity-1.0',
  fallback: ['libsingularity', 'libsingularity_dep']
)

if not meson.is_subproject() and libsingularity_dep.type_name() == 'internal'
  libsingularity_vapi_dir = join_paths(meson.project_build_root(), 'subprojects', 'libsingularity')
  add_project_arguments(['--vapidir=' + libsingularity_vapi_dir], language: 'vala')
endif

resources = gnome.compile_resources(
  'singularity-characters-resources',
  'resources/dev.sinty.characters.gresource.xml',
  source_dir: [meson.current_source_dir() / 'data', meson.current_source_dir() / 'data' / 'icons'],
)

executable('singularity-characters',
  files('src/database.vala', 'src/search.vala', 'src/app.vala', 'src/window.vala') + [resources],
  dependencies: [gtk_dep, gee_dep, libsingularity_dep],
  install: true
)

database_test = executable('characters-test',
  files('src/database.vala', 'tests/database_test.vala'),
  dependencies: [gee_dep, dependency('gio-2.0')],
)
test('characters', database_test, env: ['CHARACTERS_DATA=' + meson.current_source_dir() / 'data' / 'characters.tsv'])

install_data('data/dev.sinty.characters.desktop',
  install_dir: get_option('datadir') / 'applications'
)

shared_module('singularity-characters-widget',
  files('widget/recent_widget.vala'),
  dependencies: [gtk_dep, libsingularity_dep],
  install: true,
  install_dir: get_option('libdir') / 'singularity' / 'widgets'
)

install_data('widget/dev.sinty.characters.recent.widget',
  install_dir: get_option('datadir') / 'singularity' / 'widgets'
)

install_data('data/dev.sinty.characters.search-provider.ini',
  rename: 'dev.sinty.characters.ini',
  install_dir: get_option('datadir') / 'singularity' / 'search-providers'
)

service_conf = configuration_data()
service_conf.set('bindir', get_option('prefix') / get_option('bindir'))
configure_file(
  input: 'data/dev.sinty.characters.service.in',
  output: 'dev.sinty.characters.service',
  configuration: service_conf,
  install_dir: get_option('datadir') / 'dbus-1' / 'services'
)

install_data('data/dev.sinty.characters.gschema.xml',
  install_dir: get_option('datadir') / 'glib-2.0' / 'schemas'
)

install_data('data/icons/dev.sinty.characters.svg',
  install_dir: get_option('datadir') / 'icons' / 'hicolor' / 'scalable' / 'apps'
)
