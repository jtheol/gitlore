# frozen_string_literal: true

require "gitlore"

RSpec.describe Gitlore do
  it "has a version number" do
    expect(Gitlore::VERSION).not_to be nil
  end

  it "summarizes git commits" do
    expect(Gitlore.summarize_git).not_to be nil
  end
end
