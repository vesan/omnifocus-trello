require "open-uri"
require "json"
require "yaml"

module OmniFocus::Trello
  PREFIX  = "TR"
  KEY = "3ad9e72a2e2d41a98450ca775a0bafe4"

  def load_or_create_config
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
    config     = load_or_create_config
    token      = config[:token]
    done_lists = config[:done_lists]

    boards = fetch_boards(token)
    fetch_cards(token).each do |card|
      process_card(boards, done_lists, card)
    end
  end

  def fetch_cards(token)
    url = "https://api.trello.com/1/members/my/cards?key=#{KEY}&token=#{token}"

    JSON.parse(open(url).read)
  end

  def process_card(boards, done_lists, card)
    number       = card["idShort"]
    url          = card["shortUrl"]
    board        = boards.find {|board| board["id"] == card["idBoard"] }
    project_name = board["name"]
    ticket_id    = "#{PREFIX}-#{project_name}##{number}"
    title        = "#{ticket_id}: #{card["name"]}"
    list         = board["lists"].find {|list| list["id"] == card["idList"] }

    # If card is in a "done" list, mark it as completed.
    if done_lists.include?(list["name"])
      return
    end

    if existing[ticket_id]
      bug_db[existing[ticket_id]][ticket_id] = true
      return
    end

    bug_db[project_name][ticket_id] = [title, url]
  end

  def fetch_boards(token)
    url = "https://api.trello.com/1/members/my/boards?key=#{KEY}&token=#{token}&lists=open"
    JSON.parse(open(url).read)
  end
end
