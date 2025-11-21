require "test_helper"

class EpisodeTest < ActiveSupport::TestCase
  test "alternate_titles_text reader and writer" do
    episode = Episode.new(title: "Test", show: shows(:office))
    episode.alternate_titles_text = "name one, name two"
    assert_equal [ "name one", "name two" ], episode.alternate_titles
    assert_equal "name one, name two", episode.alternate_titles_text
  end
end
