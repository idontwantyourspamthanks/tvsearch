admin_email = ENV.fetch("ADMIN_EMAIL", "admin@example.com")
admin_password = ENV.fetch("ADMIN_PASSWORD", "changeme123")

AdminUser.find_or_create_by!(email: admin_email) do |admin|
  admin.password = admin_password
end

shows = [
  { name: "The Office", description: "A mockumentary on the everyday lives of office coworkers." },
  { name: "Breaking Bad", description: "A chemistry teacher turns to making meth to secure his family’s future." },
  { name: "Stranger Things", description: "Kids uncover a supernatural mystery in Hawkins, Indiana." },
  { name: "Succession", description: "The Roy family battles for control of a media empire." },
  { name: "The Mandalorian", description: "A lone bounty hunter protects a mysterious child in the Star Wars galaxy." }
]

shows.each { |attrs| Show.find_or_create_by!(name: attrs[:name]) { |show| show.description = attrs[:description] } }

episodes = [
  {
    show_name: "The Office",
    title: "Dinner Party",
    season_number: 4,
    episode_number: 13,
    description: "Michael and Jan host an incredibly awkward dinner that unravels in front of the Scranton crew.",
    aired_on: Date.new(2008, 4, 10)
  },
  {
    show_name: "Breaking Bad",
    title: "Ozymandias",
    season_number: 5,
    episode_number: 14,
    description: "Walt’s empire collapses as family and foes converge in the desert.",
    aired_on: Date.new(2013, 9, 15)
  },
  {
    show_name: "Stranger Things",
    title: "The Upside Down",
    season_number: 1,
    episode_number: 8,
    description: "Joyce and Hopper enter the Upside Down while the kids face down the Demogorgon.",
    aired_on: Date.new(2016, 7, 15)
  },
  {
    show_name: "Succession",
    title: "All the Bells Say",
    season_number: 3,
    episode_number: 9,
    description: "The Roy siblings scramble for leverage as a seismic change looms over Waystar.",
    aired_on: Date.new(2021, 12, 12)
  },
  {
    show_name: "The Mandalorian",
    title: "Chapter 16: The Rescue",
    season_number: 2,
    episode_number: 8,
    description: "Mando and allies attempt to rescue Grogu from Moff Gideon’s cruiser.",
    aired_on: Date.new(2020, 12, 18)
  }
]

episodes.each do |attrs|
  show = Show.find_by!(name: attrs.delete(:show_name))
  Episode.find_or_create_by!(show: show, title: attrs[:title]) do |episode|
    episode.assign_attributes(attrs.merge(show: show))
  end
end
