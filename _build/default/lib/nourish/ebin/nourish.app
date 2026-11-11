{application,nourish,
             [{description,"Neighborhood food rescue pilot"},
              {vsn,"0.1.0"},
              {registered,[nourish_sup,nourish_offers]},
              {mod,{nourish_app,[]}},
              {applications,[kernel,stdlib,crypto,cowboy]},
              {env,[{port,8080}]},
              {modules,[nourish_app,nourish_events,nourish_http,
                        nourish_offers,nourish_page,nourish_sup]}]}.
