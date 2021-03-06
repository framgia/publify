require 'spec_helper'

describe Admin::ContentController do
  render_views

  let!(:blog) { create(:blog) }
  let!(:article) { create(:article) }

  context "as publisher (admin can do the same)" do
    let!(:user) { create(:user, :as_publisher) }
    before(:each) { request.session = { user: user.id } }

    describe 'index' do
      context "simple query" do
        before(:each) { get :index }
        it { expect(response).to be_success }
        it { expect(response).to render_template('index', layout: 'administration') }
      end

      it "return article that match with search query" do
        get :index, search: {searchstring: article.body[0..4]}
        expect(assigns(:articles)).to eq([article])
      end

      it "search query and limit on published_at" do
        get :index, search: {
          searchstring: article.body[0..4],
          published_at: article.published_at + 2.days
        }
        expect(assigns(:articles)).to be_empty
      end

      context "search for state" do
        let!(:draft_article) { create(:article, state: 'draft') }
        let!(:pending_article) { create(:article, state: 'publication_pending', published_at: '2020-01-01') }
        before(:each) { get :index, search: state }

        context "draft only" do
          let(:state) {{ state: 'drafts' }}
          it { expect(assigns(:articles)).to eq([draft_article]) }
        end

        context "publication_pending only" do
          let(:state) { { state: 'pending' } }
          it { expect(assigns(:articles)).to eq([pending_article]) }
        end

        context "with a bad state" do
          let(:state) {{ state: '3vI1 1337 h4x0r'} }
          it { expect(assigns(:articles).sort).to eq([article, pending_article, draft_article].sort) }
        end
      end
    end

    describe :autosave do
      context "first time save" do
        it { expect{
          xhr :post, :autosave, article: attributes_for(:article)
        }.to change(Article, :count).from(1).to(2) }

        it { expect{
          xhr :post, :autosave, article: attributes_for(:article, :with_tags)
        }.to change(Tag, :count).from(0).to(2) }
      end

      context "second call to save" do
        let!(:draft) { create(:article, published: false, state: 'draft') }
        it { expect{
          xhr :post, :autosave, article: {id: draft.id, body_and_extended: 'new body' }
        }.to_not change(Article, :count) }
      end

      context "with an other existing draft" do
        let!(:draft) { create(:article, published: false, state: 'draft', body: 'existing body') }
        it { expect{
          xhr :post, :autosave, article: attributes_for(:article)
        }.to change(Article, :count).from(2).to(3) }

        it "dont replace existing draft" do
          xhr :post, :autosave, article: attributes_for(:article)
          expect(assigns(:article).id).to_not eq(draft.id)
          expect(assigns(:article).body).to_not eq(draft.body)
        end
      end
    end

    describe 'new' do
      before(:each) { get :new }
      it { expect(response).to be_success }
      it { expect(response).to render_template('new') }
      it { expect(assigns(:article)).to_not be_nil }
      it { expect(assigns(:article).redirects).to be_empty }
    end

    describe :create do

      let(:article_params) {{title: 'posted via tests!', body: 'a good boy'}}

      context "create an article" do
        it { expect{
          post :create, article: article_params
        }.to change(Article, :count).from(1).to(2) }
      end

      context "classic" do

        before(:each) { post :create, article: article_params }

        it { expect(response).to redirect_to(action: :index) }
        it { expect(flash[:success]).to eq(I18n.t('admin.content.create.success')) }

        it { expect(assigns(:article)).to be_published }
        it { expect(assigns(:article).user).to eq(user) }

        context "when doing a draft" do
          let(:article_params) {{title: 'posted via tests!', body: 'a good boy', state: 'draft'}}
          it { expect(assigns(:article)).to_not be_published }
        end
      end

      context "write for futur" do
        let(:article_params) {{title: 'posted via tests!', body: 'a good boy', state: 'draft', published_at: (Time.now + 1.hour).to_s}}

        it { expect{
          post :create, article: article_params
        }.to change(Article, :count).from(1).to(2) }

        it { expect{
          post :create, article: article_params
        }.to_not change(Redirection, :count) }

        it { expect{
          post :create, article: article_params
        }.to change(Trigger, :count).from(0).to(1) }
      end
    end
  end

  shared_examples_for 'create action' do
    def base_article(options={})
      { :title => "posted via tests!",
        :body => "A good body",
        :allow_comments => '1',
        :allow_pings => '1' }.merge(options)
    end

    it 'should send notifications on create' do
      begin
        u = create(:user, :notify_via_email => true, :notify_on_new_articles => true)
        u.save!
        ActionMailer::Base.perform_deliveries = true
        ActionMailer::Base.deliveries.clear
        emails = ActionMailer::Base.deliveries

        post :create, 'article' => base_article

        assert_equal(1, emails.size)
        assert_equal(u.email, emails.first.to[0])
      ensure
        ActionMailer::Base.perform_deliveries = false
      end
    end

    it 'should create an article with tags' do
      post :create, 'article' => base_article(:keywords => "foo bar")
      new_article = Article.last
      assert_equal 2, new_article.tags.size
    end

    it "should correctly interpret time zone in :published_at" do
      post :create, 'article' => base_article(:published_at => "February 17, 2011 08:47 PM GMT+0100 (CET)")
      new_article = Article.last
      assert_equal Time.utc(2011, 2, 17, 19, 47), new_article.published_at
    end

    it 'should respect "GMT+0000 (UTC)" in :published_at' do
      post :create, 'article' => base_article(:published_at => 'August 23, 2011 08:40 PM GMT+0000 (UTC)')
      new_article = Article.last
      assert_equal Time.utc(2011, 8, 23, 20, 40), new_article.published_at
    end

    it 'should create a filtered article' do
      Article.delete_all
      body = "body via *markdown*"
      extended="*foo*"
      post :create, 'article' => { :title => "another test", :body => body, :extended => extended}

      assert_response :redirect, :action => 'index'

      new_article = Article.order(created_at: :desc).first

      new_article.body.should eq body
      new_article.extended.should eq extended
      new_article.text_filter.name.should eq @user.text_filter.name
      new_article.html(:body).should eq "<p>body via <em>markdown</em></p>"
      new_article.html(:extended).should eq "<p><em>foo</em></p>"
    end

    context "with a previously autosaved draft" do
      before do
        @draft = create(:article, body: 'draft', state: 'draft', published: false)
        post(:create, article: {id: @draft.id, body: 'update', published: true})
      end

      it "updates the draft" do
        Article.find(@draft.id).body.should eq 'update'
      end

      it "makes the draft published" do
        Article.find(@draft.id).should be_published
      end
    end

    describe "with an unrelated draft in the database" do
      before do
        @draft = create(:article, :state => 'draft')
      end

      describe "saving new article as draft" do
        it "leaves the original draft in existence" do
          post :create, article: base_article({:draft => 'save as draft'})
          assigns(:article).id.should_not == @draft.id
          Article.find(@draft.id).should_not be_nil
        end
      end
    end
  end

  describe 'with admin connection' do
    before(:each) do
      @user = create(:user, :as_admin, text_filter: create(:markdown))
      request.session = { :user => @user.id }
      @article = create(:article)
    end

    it_should_behave_like 'create action'

    describe 'edit action' do
      it 'should edit article' do
        get :edit, 'id' => @article.id
        response.should render_template 'edit'
        assigns(:article).should_not be_nil
        assigns(:article).should be_valid
        response.body.should match(/body/)
        response.body.should match(/extended content/)
      end

      it "correctly converts multi-word tags" do
        a = create(:article, :keywords => '"foo bar", baz')
        get :edit, :id => a.id
        response.body.should have_selector("input[id=article_keywords][value='baz, \"foo bar\"']")
      end
    end

    describe 'update action' do
      it 'should update article' do
        begin
          ActionMailer::Base.perform_deliveries = true
          emails = ActionMailer::Base.deliveries
          emails.clear

          art_id = @article.id

          body = "another *textile* test"
          put :update, 'id' => art_id, 'article' => {:body => body, :text_filter => 'textile'}
          assert_response :redirect, :action => 'show', :id => art_id

          article = @article.reload
          article.text_filter.name.should == "textile"
          body.should == article.body

          emails.size.should == 0
        ensure
          ActionMailer::Base.perform_deliveries = false
        end
      end

      it 'should allow updating body_and_extended' do
        article = @article
        put :update, 'id' => article.id, 'article' => {
          'body_and_extended' => 'foo<!--more-->bar<!--more-->baz'
        }
        assert_response :redirect
        article.reload
        article.body.should == 'foo'
        article.extended.should == 'bar<!--more-->baz'
      end

      it 'should delete draft about this article if update' do
        attributes = @article.attributes.except("id").merge(:state => 'draft', :parent_id => @article.id, :guid => nil)
        draft = Article.create!(attributes)
        lambda do
          put :update, 'id' => @article.id, 'article' => { 'title' => 'new'}
        end.should change(Article, :count).by(-1)
        Article.should_not be_exists({:id => draft.id})
      end

      it 'should delete all draft about this article if update not happen but why not' do
        attributes = @article.attributes.except("id").merge(:state => 'draft', :parent_id => @article.id, :guid => nil)
        draft = Article.create!(attributes)
        draft_2 = Article.create!(attributes)
        lambda do
          put :update, 'id' => @article.id, 'article' => { 'title' => 'new'}
        end.should change(Article, :count).by(-2)
        Article.should_not be_exists({:id => draft.id})
        Article.should_not be_exists({:id => draft_2.id})
      end

      describe "publishing a published article with an autosaved draft" do
        before do
          @orig = create(:article)
          @draft = create(:article, :parent_id => @orig.id, :state => 'draft', :published => false)
          put(:update,
              :id => @orig.id,
              :article => {:id => @draft.id, :body => 'update'})
        end

        it "updates the original" do
          Article.find(@orig.id).body.should == 'update'
        end

        it "deletes the draft" do
          assert_raises ActiveRecord::RecordNotFound do
            Article.find(@draft.id)
          end
        end
      end

      describe "publishing a draft copy of a published article" do
        before do
          @orig = create(:article)
          @draft = create(:article, :parent_id => @orig.id, :state => 'draft', :published => false)
          put(:update,
              :id => @draft.id,
              :article => {:id => @draft.id, :body => 'update'})
        end

        it "updates the original" do
          Article.find(@orig.id).body.should == 'update'
        end

        it "deletes the draft" do
          assert_raises ActiveRecord::RecordNotFound do
            Article.find(@draft.id)
          end
        end
      end

      describe "saving a published article as draft" do
        before do
          @orig = create(:article)
          put(:update,
              :id => @orig.id,
              :article => {:title => @orig.title, :draft => 'draft',
                           :body => 'update' })
        end

        it "leaves the original published" do
          @orig.reload
          @orig.published.should == true
        end

        it "leaves the original as is" do
          @orig.reload
          @orig.body.should_not == 'update'
        end

        it "redirects to the index" do
          response.should redirect_to(:action => 'index')
        end

        it "creates a draft" do
          draft = Article.child_of(@orig.id).first
          draft.parent_id.should == @orig.id
          draft.should_not be_published
        end
      end
    end

    describe 'auto_complete_for_article_keywords action' do
      before do
        create(:tag, :name => 'foo', :articles => [create(:article)])
        create(:tag, :name => 'bazz', :articles => [create(:article)])
        create(:tag, :name => 'bar', :articles => [create(:article)])
      end

      it 'should return foo for keywords fo' do
        get :auto_complete_for_article_keywords, :article => {:keywords => 'fo'}
        response.should be_success
        response.body.should == "[\"bar\", \"bazz\", \"foo\"]"
      end
    end
  end

  describe 'common behavior with publisher connection' do
    let!(:user) { create(:user, text_filter: create(:markdown), profile: create(:profile_publisher)) }

    before :each do
      user.save
      @user = user
      @article = create(:article, user: user)
      request.session = {user: user.id}
    end

    it_should_behave_like 'create action'
  end

  describe 'with publisher connection' do
    let!(:user) { create(:user, text_filter: create(:markdown), profile: create(:profile_publisher)) }

    before(:each) { request.session = {user: user.id} }

    describe :edit do
      context "with an article from an other user" do
        let!(:article) { create(:article, user: create(:user, login: 'another_user')) }

        before(:each) { get :edit, id: article.id }
        it { expect(response).to redirect_to(action: 'index') }
      end

      context "with an article from current user" do
        let!(:article) { create(:article, user: user) }

        before(:each) { get :edit, id: article.id }
        it { expect(response).to render_template('edit') }
        it { expect(assigns(:article)).to_not be_nil }
        it { expect(assigns(:article)).to be_valid }
      end
    end

    describe :update do
      context "with an article" do
        let!(:article) { create(:article, body: "another *textile* test", user: user) }
        let!(:body) { "not the *same* text" }
        before(:each) { put :update, id: article.id, article: {body: body, text_filter: 'textile'} }
        it { expect(response).to redirect_to(action: 'index') }
        it { expect(article.reload.text_filter.name).to eq('textile') }
        it { expect(article.reload.body).to eq(body) }
      end
    end

    describe :destroy do
      context "with post method" do
        context "with an article from other user" do
          let(:article) { create(:article, user: create(:user, login: 'other_user')) }

          before(:each) { post :destroy, id: article.id }
          it { expect(response).to redirect_to(action: 'index') }
          it { expect(Article.count).to eq(1) }
        end

        context "with an article from user" do
          let(:article) { create(:article, user: user) }
          before(:each) { post :destroy, id: article.id }
          it { expect(response).to redirect_to(action: 'index') }
          it { expect(Article.count).to eq(0) }
        end
      end

      context "with get method" do
        context "with an article from other user" do
          let(:article) { create(:article, user: create(:user, login: 'other_user')) }

          before(:each) { get :destroy, id: article.id }
          it { expect(response).to redirect_to(action: 'index') }
          it { expect(Article.count).to eq(1) }
        end

        context "with an article from user" do
          let(:article) { create(:article, user: user) }
          before(:each) { get :destroy, id: article.id }
          it { expect(response).to render_template('admin/shared/destroy') }
          it { expect(Article.count).to eq(1) }
        end
      end
    end
  end
end
