class ApiController < ApplicationController
    skip_before_action :verify_authenticity_token

    def index
        question_text = params[:question]

        render json: {
            answer: "",
            question: question_text
        }
    end
  end
  