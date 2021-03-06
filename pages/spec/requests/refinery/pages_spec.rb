# encoding: utf-8
require 'spec_helper'

module Refinery
  describe 'page frontend' do
    let(:home_page) { FactoryGirl.create(:page, :title => 'Home', :link_url => '/') }
    let(:about_page) { FactoryGirl.create(:page, :title => 'About') }
    let(:draft_page) { FactoryGirl.create(:page, :title => 'Draft', :draft => true) }
    before(:each) do
      # So that we can use Refinery.
      Refinery::PagesController.any_instance.stub(:refinery_user_required?).and_return(false)

      # Stub the menu pages we're expecting
      Refinery::Page.stub(:fast_menu).and_return([home_page, about_page])
    end

    def standard_page_menu_items_exist?
      within('.menu') do
        page.should have_content(home_page.title)
        page.should have_content(about_page.title)
        page.should_not have_content(draft_page.title)
      end
    end

    describe 'when marketable urls are' do
      describe 'enabled' do
        before { Refinery::Pages.stub(:marketable_urls).and_return(true) }

        it 'shows the homepage' do
          Refinery::PagesController.any_instance.stub(:find_page).and_return(:home_page)
          visit '/'

          standard_page_menu_items_exist?
        end

        it 'shows a show page' do
          Refinery::PagesController.any_instance.stub(:find_page).and_return(:about_page)
          visit refinery.page_path(about_page)

          standard_page_menu_items_exist?
        end
      end

      describe 'disabled' do
        before { Refinery::Pages.stub(:marketable_urls).and_return(false) }

        it 'shows the homepage' do
          Refinery::PagesController.any_instance.stub(:find_page).and_return(:home_page)
          visit '/'

          standard_page_menu_items_exist?
        end

        it 'does not route to /about for About page' do
          refinery.page_path(about_page).should =~ %r{/pages/about$}
        end

        it 'shows the about page' do
          Refinery::PagesController.any_instance.stub(:find_page).and_return(:about_page)
          visit refinery.page_path(about_page)

          standard_page_menu_items_exist?
        end
      end
    end

    describe 'title set (without menu title or browser title)' do
      before(:each) { visit '/about' }

      it "shows title at the top of the page" do
        find("#body_content_title").text.should == about_page.title
      end

      it "uses title in the menu" do
        find(".selected").text.strip.should == about_page.title
      end

      it "uses title in browser title" do
        find("title").should have_content(about_page.title)
      end
    end

    describe 'when menu_title is' do
      let(:page_mt) { FactoryGirl.create(:page, :title => 'Company News') }

      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([page_mt])
      end

      describe 'set' do
        before do
          page_mt.menu_title = "News"
          page_mt.save
        end

        it 'shows the menu_title in the menu' do
          visit '/news'

          find(".selected").text.strip.should == page_mt.menu_title
        end

        it "does not effect browser title and page title" do
          visit "/news"

          find("title").should have_content(page_mt.title)
          find("#body_content_title").text.should == page_mt.title
        end
      end

      describe 'set and then unset' do
        before do
          page_mt.menu_title = "News"
          page_mt.save
          page_mt.menu_title = ""
          page_mt.save
        end

        it 'the friendly_id and menu are reverted to match the title' do
          visit '/company-news'

          current_path.should == '/company-news'
          find(".selected").text.strip.should == page_mt.title
        end
      end
    end

    describe 'when browser_title is set' do
      let(:page_bt) { FactoryGirl.create(:page, :title => 'About Us', :browser_title => 'About Our Company') }
      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([page_bt])
      end
      it 'should have the browser_title in the title tag' do
        visit '/about-us'

        page.find("title").text == page_bt.title
      end

      it 'should not effect page title and menu title' do
        visit '/about-us'

        find("#body_content_title").text.should == page_bt.title
        find(".selected").text.strip.should == page_bt.title
      end
    end

    describe 'custom_slug' do
      let(:page_cs) { FactoryGirl.create(:page, :title => 'About Us') }
      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([page_cs])
      end

      describe 'not set' do
        it 'makes friendly_id from title' do
          visit '/about-us'

          current_path.should == '/about-us'
        end
      end

      describe 'set' do
        before do
          page_cs.custom_slug = "about-custom"
          page_cs.save
        end

        it 'should make and use a new friendly_id' do
          visit '/about-custom'

          current_path.should == '/about-custom'
        end
      end

      describe 'set and unset' do
        before do
          page_cs.custom_slug = "about-custom"
          page_cs.save
          page_cs.custom_slug = ""
          page_cs.save
          page_cs.reload
        end
      end
    end

    # Following specs are converted from one of the cucumber features.
    # Maybe we should clean up this spec file a bit...
    describe "home page" do
      it "succeeds" do
        visit "/"

        within ".selected" do
          page.should have_content(home_page.title)
        end
        page.should have_content(about_page.title)
      end
    end

    describe "content page" do
      it "succeeds" do
        visit "/about"

        page.should have_content(home_page.title)
        within ".selected > a" do
          page.should have_content(about_page.title)
        end
      end
    end

    describe "submenu page" do
      let(:submenu_page) {
        FactoryGirl.create(:page, :title => 'Sample Submenu', :parent_id => about_page.id)
      }

      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([home_page, submenu_page, about_page.reload].sort_by(&:lft))
      end

      it "succeeds" do
        visit refinery.url_for(submenu_page.url)
        page.should have_content(home_page.title)
        page.should have_content(about_page.title)
        within ".selected * > .selected a" do
          page.should have_content(submenu_page.title)
        end
      end
    end

    describe "special characters title" do
      let(:special_page) { FactoryGirl.create(:page, :title => 'ä ö ü spéciål chåråctÉrs') }
      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([home_page, about_page, special_page])
      end

      it "succeeds" do
        visit refinery.url_for(special_page.url)

        page.should have_content(home_page.title)
        page.should have_content(about_page.title)
        within ".selected > a" do
          page.should have_content(special_page.title)
        end
      end
    end

    describe "special characters title as submenu page" do
      let(:special_page) { FactoryGirl.create(:page, :title => 'ä ö ü spéciål chåråctÉrs',
                                                     :parent_id => about_page.id) }

      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([home_page, special_page, about_page.reload].sort_by(&:lft))
      end

      it "succeeds" do
        visit refinery.url_for(special_page.url)

        page.should have_content(home_page.title)
        page.should have_content(about_page.title)
        within ".selected * > .selected a" do
          page.should have_content(special_page.title)
        end
      end
    end

    describe "hidden page" do
      let(:hidden_page) { FactoryGirl.create(:page, :title => "Hidden", :show_in_menu => false) }

      before(:each) do
        Refinery::Page.stub(:fast_menu).and_return([home_page, about_page])
      end

      it "succeeds" do
        visit refinery.page_path(hidden_page)

        page.should have_content(home_page.title)
        page.should have_content(about_page.title)
        page.should have_content(hidden_page.title)
        within "nav" do
          page.should have_no_content(hidden_page.title)
        end
      end
    end

    describe "skip to first child" do
      let(:child_page) { FactoryGirl.create(:page, :title => "Child Page", :parent_id => about_page.id)}
      before(:each) do
       child_page
       about = about_page.reload
       about.skip_to_first_child = true
       about.save!

       Refinery::Page.stub(:fast_menu).and_return([home_page, about, child_page].sort_by(&:lft))
      end

      it "succeeds" do
        visit "/about"

        within ".selected * > .selected a" do
          page.should have_content(child_page.title)
        end
      end
    end
  end
end
