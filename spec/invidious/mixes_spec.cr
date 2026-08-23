require "../parsers_helper.cr"
require "../../src/invidious/mixes"

# `extract_mix_video_ucid` guards the one field in a mix entry that YouTube does
# not always send. Before the guard, a single entry without `browseEndpoint`
# raised `KeyError`, and the API route's blanket `rescue` turned that into a 500
# for the entire mix — so one multi-artist track discarded every other track in
# the response.
Spectator.describe "extract_mix_video_ucid" do
  # The ordinary shape: one artist, channel id present.
  it "returns the channel id when browseEndpoint is present" do
    item = JSON.parse(<<-JSON)
      {"longBylineText": {"runs": [{
        "text": "Some Artist",
        "navigationEndpoint": {"browseEndpoint": {"browseId": "UC_test_channel_id"}}
      }]}}
      JSON

    expect(extract_mix_video_ucid(item)).to eq("UC_test_channel_id")
  end

  # The shape that caused the outage. A byline crediting two artists carries a
  # showDialogCommand — a picker — instead of a browseEndpoint. This is real
  # response shape, not a hypothetical: it is what "Madhur Sharma and Universal
  # Music India" returned.
  it "returns a blank id when the byline is a multi-artist dialog instead" do
    item = JSON.parse(<<-JSON)
      {"longBylineText": {"runs": [{
        "text": "Madhur Sharma and Universal Music India",
        "navigationEndpoint": {"showDialogCommand": {"panelLoadingStrategy": {}}}
      }]}}
      JSON

    expect(extract_mix_video_ucid(item)).to eq("")
  end

  # Defence in depth: every level of the path is optional, because a truncated or
  # unfamiliar payload must cost one field rather than the whole request.
  it "returns a blank id when navigationEndpoint is missing entirely" do
    item = JSON.parse(%({"longBylineText": {"runs": [{"text": "Some Artist"}]}}))
    expect(extract_mix_video_ucid(item)).to eq("")
  end

  it "returns a blank id when runs is empty" do
    item = JSON.parse(%({"longBylineText": {"runs": []}}))
    expect(extract_mix_video_ucid(item)).to eq("")
  end

  it "returns a blank id when longBylineText is absent" do
    item = JSON.parse(%({"title": {"simpleText": "A track"}}))
    expect(extract_mix_video_ucid(item)).to eq("")
  end

  # browseId is typed as a string; anything else must not raise either.
  it "returns a blank id when browseId is not a string" do
    item = JSON.parse(<<-JSON)
      {"longBylineText": {"runs": [{
        "navigationEndpoint": {"browseEndpoint": {"browseId": 12345}}
      }]}}
      JSON

    expect(extract_mix_video_ucid(item)).to eq("")
  end
end
