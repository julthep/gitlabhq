# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Creating a Snippet' do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:description) { 'Initial description' }
  let(:title) { 'Initial title' }
  let(:visibility_level) { 'public' }
  let(:action) { :create }
  let(:file_1) { { filePath: 'example_file1', content: 'This is the example file 1' }}
  let(:file_2) { { filePath: 'example_file2', content: 'This is the example file 2' }}
  let(:actions) { [{ action: action }.merge(file_1), { action: action }.merge(file_2)] }
  let(:project_path) { nil }
  let(:uploaded_files) { nil }
  let(:mutation_vars) do
    {
      description: description,
      visibility_level: visibility_level,
      title: title,
      project_path: project_path,
      uploaded_files: uploaded_files,
      blob_actions: actions
    }
  end

  let(:mutation) do
    graphql_mutation(:create_snippet, mutation_vars)
  end

  def mutation_response
    graphql_mutation_response(:create_snippet)
  end

  subject { post_graphql_mutation(mutation, current_user: current_user) }

  context 'when the user does not have permission' do
    let(:current_user) { nil }

    it_behaves_like 'a mutation that returns top-level errors',
                    errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]

    it 'does not create the Snippet' do
      expect do
        subject
      end.not_to change { Snippet.count }
    end

    context 'when user is not authorized in the project' do
      let(:project_path) { project.full_path }

      it 'does not create the snippet when the user is not authorized' do
        expect do
          subject
        end.not_to change { Snippet.count }
      end
    end
  end

  context 'when the user has permission' do
    let(:current_user) { user }

    shared_examples 'does not create snippet' do
      it 'does not create the Snippet' do
        expect do
          subject
        end.not_to change { Snippet.count }
      end

      it 'does not return Snippet' do
        subject

        expect(mutation_response['snippet']).to be_nil
      end
    end

    shared_examples 'creates snippet' do
      it 'returns the created Snippet' do
        expect do
          subject
        end.to change { Snippet.count }.by(1)

        expect(mutation_response['snippet']['title']).to eq(title)
        expect(mutation_response['snippet']['description']).to eq(description)
        expect(mutation_response['snippet']['visibilityLevel']).to eq(visibility_level)
        expect(mutation_response['snippet']['blobs'][0]['plainData']).to match(file_1[:content])
        expect(mutation_response['snippet']['blobs'][0]['fileName']).to match(file_1[:file_path])
        expect(mutation_response['snippet']['blobs'][1]['plainData']).to match(file_2[:content])
        expect(mutation_response['snippet']['blobs'][1]['fileName']).to match(file_2[:file_path])
      end

      context 'when action is invalid' do
        let(:file_1) { { filePath: 'example_file1' }}

        it_behaves_like 'a mutation that returns errors in the response', errors: ['Snippet actions have invalid data']
        it_behaves_like 'does not create snippet'
      end
    end

    context 'with PersonalSnippet' do
      it_behaves_like 'creates snippet'
    end

    context 'with ProjectSnippet' do
      let(:project_path) { project.full_path }

      before do
        project.add_developer(current_user)
      end

      it_behaves_like 'creates snippet'

      context 'when the project path is invalid' do
        let(:project_path) { 'foobar' }

        it_behaves_like 'a mutation that returns top-level errors',
                        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end

      context 'when the feature is disabled' do
        before do
          project.project_feature.update_attribute(:snippets_access_level, ProjectFeature::DISABLED)
        end

        it_behaves_like 'a mutation that returns top-level errors',
                        errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
      end
    end

    context 'when there are ActiveRecord validation errors' do
      let(:title) { '' }

      it_behaves_like 'a mutation that returns errors in the response', errors: ["Title can't be blank"]
      it_behaves_like 'does not create snippet'
    end

    context 'when there non ActiveRecord errors' do
      let(:file_1) { { filePath: 'invalid://file/path', content: 'foobar' }}

      it_behaves_like 'a mutation that returns errors in the response', errors: ['Repository Error creating the snippet - Invalid file name']
      it_behaves_like 'does not create snippet'
    end

    context 'when there are uploaded files' do
      shared_examples 'expected files argument' do |file_value, expected_value|
        let(:uploaded_files) { file_value }

        it do
          expect(::Snippets::CreateService).to receive(:new).with(nil, user, hash_including(files: expected_value))

          subject
        end
      end

      it_behaves_like 'expected files argument', nil, nil
      it_behaves_like 'expected files argument', %w(foo bar), %w(foo bar)
      it_behaves_like 'expected files argument', 'foo', %w(foo)

      context 'when files has an invalid value' do
        let(:uploaded_files) { [1] }

        it 'returns an error' do
          subject

          expect(json_response['errors']).to be
        end
      end
    end
  end
end
