class RodaApp < Roda
  plugin :bridgetown_server

  route do |r|
    r.bridgetown
  end
end
