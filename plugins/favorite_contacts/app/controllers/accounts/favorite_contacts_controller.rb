class Accounts::FavoriteContactsController < InternalController
  before_action :set_contact, only: %i[create destroy]

  def index
    @favorite_contacts = current_user.favorite_contacts
                                     .includes(:contact)
                                     .order(created_at: :desc)
    @pagy, @favorite_contacts = pagy(@favorite_contacts)
  end

  def create
    @favorite_contact = current_user.favorite_contacts.find_or_initialize_by(contact: @contact)

    if @favorite_contact.persisted? || @favorite_contact.save
      @contact.reload
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_back fallback_location: account_contacts_path(Current.account) }
      end
    else
      redirect_back fallback_location: account_contacts_path(Current.account),
                    alert: @favorite_contact.errors.full_messages.to_sentence
    end
  end

  def destroy
    @favorite_contact = current_user.favorite_contacts.find_by(contact: @contact)
    @favorite_contact&.destroy
    @contact.reload

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back fallback_location: account_contacts_path(Current.account) }
    end
  end

  private

  def set_contact
    @contact = Contact.find(params[:contact_id])
  end
end
