
module Hooky
  module Postgresql

    DEFAULT_PRIVILEGES = [
      {
        :privilege => "ALL PRIVILEGES",
        :type => "DATABASE",
        :column => nil,
        :on => "gonano",
        :with_grant => true
      }
    ]

    DEFAULT_META = {
      :privileges => DEFAULT_PRIVILEGES,
      :roles => [
        "SUPERUSER"
      ]
    }

    DEFAULT_USERS = [
      {
        :username => "nanobox",
        :meta => DEFAULT_META
      }
    ]

    USER_META_PRVILIGES_DEFAULTS = {
      privilege:    {type: :string, from: ["SELECT", "INSERT", "UPDATE", "DELETE", "TRUNCATE", "REFERENCES", "TRIGGER", "ALL", "ALL PRIVILEGES", "USAGE", "CREATE", "CONNECT", "TEMPORARY", "TEMP", "EXECUTE"], default: "SELECT"},
      type:         {type: :string, from: ["TABLE", "ALL TABLES IN SCHEMA", "SEQUENCE", "ALL SEQUENCES IN SCHEMA", "DATABASE", "FOREIGN DATA WRAPPER", "FOREIGN SERVER", "FUNCTION", "ALL FUNCTIONS IN SCHEMA", "LANGUAGE", "LARGE OBJECT", "SCHEMA", "TABLESPACE"], default: "DATABASE"},
      column:       {type: :string, default: nil},
      on:           {type: :string, default: 'gonano'},
      with_grant:   {type: :on_off, default: false}
    }

    USER_META_DEFAULTS = {
      privileges:    {type: :array, of: :hash, template: USER_META_PRVILIGES_DEFAULTS, default: DEFAULT_PRIVILEGES},
      roles:         {type: :array, of: :string, default: []}
    }

    USER_DEFAULTS = {
      username:      {type: :string, default: 'gonano'},
      meta:          {type: :hash, template: USER_META_DEFAULTS, default: DEFAULT_META}
    }

    CONFIG_DEFAULTS = {
      # global settings
      before_deploy: {type: :array, of: :string, default: []},
      after_deploy:  {type: :array, of: :string, default: []},
      hook_ref:      {type: :string, default: "stable"},
      # postgresql settings
      locale:        {type: :string, default: 'en_US.UTF-8'},
      extensions:    {type: :array, of: :string, default: []},
      users:         {type: :array, of: :hash, template: USER_DEFAULTS, default: DEFAULT_USERS}
    }

    def sanitize_env_vars(payload)
      vars = payload[:environment_variables]

      # now lets enable any backwards compatible vars
      vars.inject({}) do |res, (key, val)|
        if /^DATABASE(\d+)_(.+)$/.match key
          # create the backwards compatible version
          res["DB#{$1}_#{$2}"] = val
        end
        # put the original back in
        res[key] = val
        res
      end
    end

    def check_for_ready(port=5432)
      begin
        Timeout::timeout(90) do
          begin
            execute 'try connect' do
              command "/data/bin/psql -U gonano -p #{port} postgres -c \"SELECT * FROM pg_catalog.pg_tables;\""
            end
          rescue Hookit::Error::UnexpectedExit
            sleep 1
            retry
          end
        end
      rescue Timeout::Error
        puts 'failed to connect to PostgreSQL'
        exit 1
      end
    end

  end
end
