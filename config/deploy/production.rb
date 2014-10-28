role :app, %w{deploy@localhost}
role :web, %w{deploy@localhost}
role :db,  %w{deploy@localhost}
server "localhost", user: "deploy", roles: %w{web app db}, my_property: :my_value
