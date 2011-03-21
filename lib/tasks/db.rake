namespace :db do

  desc "Load all reference data into the database"
  task :populate => :environment do

    # Load transport modes
    Rake::Task['db:seed'].execute

    # Load Localities, Regions, Districts, AdminAreas
    ENV['DIR'] = MySociety::Config.get('NPTG_DIR', '')
    Rake::Task['nptg:load:all'].execute
    Rake::Task['naptan:geo:convert_localities'].execute

    # Load Stops, StopAreas, give StopAreas lat/lon
    ENV['DIR'] = MySociety::Config.get('NAPTAN_DIR', '')
    Rake::Task['naptan:load:all'].execute

    # Load Operators
    ENV['FILE'] = File.join(MySociety::Config.get('NOC_DIR', ''), 'NOC_DB_31-03-2010.csv')
    Rake::Task['noc:load:operators'].execute

    # Some post-load cleanup on NaPTAN data - add locality to stop areas, and any stops missing locality
    Rake::Task['naptan:post_load:add_locality_to_stops'].execute
    Rake::Task['naptan:post_load:add_locality_to_stop_areas'].execute

    # Pre-load checking and loading of missing stops (needs to be run manually)
    # Requires ATCO-CIF NPTDR data to have been parsed into tsv files using script/dump_nptdr_routes.py
    # Rake::Task['nptdr:pre_load:check_stops'].execute
    # Rake::Task['nptdr:pre_load:check_routes'].execute
    # Rake::Task['nptdr:load:missing_stops'].execute


    # Load Routes
    ENV['DIR'] = File.join(MySociety::Config.get('NPTDR_DIR', ''), 'routes')
    Rake::Task['nptdr:load:routes'].execute

    # Delete stop areas without stops, other references, double-metaphone
    Rake::Task['naptan:post_load:delete_unpopulated_stop_areas'].execute
    Rake::Task['naptan:post_load:add_stops_codes'].execute
    Rake::Task['naptan:post_load:mark_metro_stops'].execute
    Rake::Task['naptan:post_load:add_station_double_metaphones'].execute

    # Delete routes with no stops, add localities and regions.
    # Associate routes with operators
    Rake::Task['nptdr:post_load:delete_routes_without_stops'].execute
    Rake::Task['nptdr:post_load:add_route_localities'].execute
    Rake::Task['nptdr:post_load:add_route_regions'].execute
    Rake::Task['nptdr:post_load:add_route_coords'].execute
    Rake::Task['nptdr:post_load:cache_route_descriptions'].execute

    # Load PTEs
    Rake::Task['pte:load']

    # Generate slugs
    Rake::Task['friendly_id:make_slugs'].execute

    # Mark records as loaded
    Rake::Task['db:mark_loaded']
  end

  desc 'Mark records as loaded - triggers stricter validation'
  task :mark_loaded => :environment do
    [Stop, StopArea, Route].each do |model_type|
      model_type.find_each do |instance|
        instance.loaded = true
        instance.save!
      end
    end
  end

  desc 'Load data from a Postgres binary dump'
  task :load_from_binary => :environment do
    check_for_file

    puts "migrating down"
    ENV['VERSION'] = '0'
    Rake::Task['db:migrate'].execute

    puts "migrating up"
    ENV.delete('VERSION')
    Rake::Task['db:migrate'].execute

    puts "deleting data"
    ActiveRecord::Base.connection.execute('DELETE FROM geometry_columns;')
    ActiveRecord::Base.connection.execute('DELETE FROM spatial_ref_sys;')
    ActiveRecord::Base.connection.execute('DELETE FROM schema_migrations;')

    puts "Loading from binary file #{ENV['FILE']}"
    port = ActiveRecord::Base.configurations[RAILS_ENV]['port']
    database = ActiveRecord::Base.configurations[RAILS_ENV]['database']
    user = ActiveRecord::Base.configurations[RAILS_ENV]['username']
    system("pg_restore --port=#{port} --disable-triggers --data-only -d #{database} -U #{user} #{ENV['FILE']}")
  end

end
