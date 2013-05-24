require "open-uri"
require "json"
require "yaml"

module OmniFocus::Trello
  PREFIX  = "TR"
  KEY = "3ad9e72a2e2d41a98450ca775a0bafe4"

  def load_or_create_trello_config
    path   = File.expand_path "~/.omnifocus-trello.yml"
    config = YAML.load(File.read(path)) rescue nil

    unless config then
      config = { :token => "Open URL https://trello.com/1/authorize?key=#{KEY}&name=OmniFocus+Trello+integration&expiration=never&response_type=token and copy the token from the web page here.", :done_boards => ["Done", "Deployed", "Finished", "Cards in these boards are considered done, you add and remove names to fit your workflow."] }

      File.open(path, "w") { |f|
        YAML.dump(config, f)
      }

      abort "Created default config in #{path}. Go fill it out."
    end

    config
  end

  def populate_trello_tasks
    config     = load_or_create_trello_config
    token      = config[:token]
    done_boards = config[:done_boards]

    boards = fetch_trello_boards(token)
    fetch_trello_cards(token).each do |card|
      process_trello_card(boards, done_boards, card)
    end
  end

  def fetch_trello_cards(token)
    url = "https://api.trello.com/1/members/my/cards?key=#{KEY}&token=#{token}"

    JSON.parse(open(url).read)
  end

  def process_trello_card(boards, done_boards, card)
    number       = card["idShort"]
    url          = card["shortUrl"]
    board        = boards.find {|board| board["id"] == card["idBoard"] }
    project_name = board["name"]
    ticket_id    = "#{PREFIX}-#{project_name}##{number}"
    title        = "#{ticket_id}: #{card["name"]}"
    list         = board["lists"].find {|list| list["id"] == card["idList"] }

    # If card is in a "done" list, mark it as completed.
    if done_boards.include?(list["name"])
      return
    end

    if existing[ticket_id]
      bug_db[existing[ticket_id]][ticket_id] = true
      return
    end

    bug_db[project_name][ticket_id] = [title, url]
  end

  def fetch_trello_boards(token)
    url = "https://api.trello.com/1/members/my/boards?key=#{KEY}&token=#{token}&lists=open"
    JSON.parse(open(url).read)
  end
end
