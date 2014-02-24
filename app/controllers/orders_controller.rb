class OrdersController < ApplicationController
  layout 'table', only: [:index, :admin, :my]
  before_action :current_user_is_admin,       only: [:admin]
  before_action :current_user_can_write,      only: [:edit, :update, :destroy]  
  before_action :current_user_can_see_orders, only: [:index]
  before_action :current_user_can_see_order,  only: [:show]
  before_action :set_order,                   only: [:show, :edit, :update, :destroy]
  before_action :corrected_qty_update_only_for_expired_offer, only: [:update]

  # GET /offers/1/orders
  def index
    @offer = Offer.find(params[:offer_id])
    @offer_items = @offer.offer_items
    
    @orders = @offer.orders.order("orders.delivery_id, orders.user_id")
        
    @proizvodi = {} 
    @orders.each do |order| 
      order.order_items.each do |order_item| 
        if order_item.offer_item 
          @proizvodi[order_item.offer_item_id] = {title: order_item.offer_item.title, unit: order_item.offer_item.unit, price: order_item.offer_item.decimal_price, icon: order_item.offer_item.packaging} 
        end  
      end 
    end
    
    @qty_sum = @offer.orders.includes(:order_items).group(:offer_item_id).sum(:qty)
    @qty_sum.each do |id, qty_sum| 
      @proizvodi[id][:qty_sum] = qty_sum.to_d 
    end


    @offer.orders.includes(:order_items).to_a.each do |order|       
      order.order_items.each do |order_item| 
        id = order_item.offer_item_id
        if @proizvodi[id][:numeric_qty_sum]
          @proizvodi[id][:numeric_qty_sum] += order_item.numeric_qty.to_d
        else
          @proizvodi[id][:numeric_qty_sum] = order_item.numeric_qty.to_d
        end
      end
    end

    @contact_form_url = message_to_orderers_offer_path(@offer)
    
    respond_to do |format|
      format.html
      format.csv { render text: 
        @offer.orders.includes(order_items: :offer_item, order_items: {order: {user: :group}}).references(order_items: :offer_item, order_items: {order: {user: :group}}).to_csv }
    end
    
  end

  # GET /my_orders
  def my_orders
    @my_orders = current_user.orders.order('updated_at DESC')
  end

  # GET /admin_orders
  def admin
    @orders = Order.order('updated_at DESC')
  end

  # GET /orders/1
  def show
  end

  # GET /orders/new
  def new
    # @order = Order.new
    @offer = Offer.find(params[:offer_id])
    @offer_items = @offer.offer_items
    @order = @offer.orders.build
  end

  # GET /orders/1/edit
  def edit
    @offer_items = @offer.offer_items
  end

  # POST /offers/1/orders
  def create
    @offer = Offer.find(params[:offer_id])
    @order = @offer.orders.build(order_params)
    @order.user = current_user

    if @order.save
      redirect_to [@offer,@order], notice: 'Order was successfully created.'
    else
      render action: 'new'
    end
  end

  # PATCH/PUT /orders/1
  def update
    if @order.update(order_params)
      if order_params_include_corrected_qty?
        redirect_to offer_orders_path(@offer), notice: 'Qty was successfully corrected.'        
      else
        redirect_to [@offer, @order], notice: 'Order was successfully updated.'
      end
    else
      render action: 'edit'
    end
  end

  # DELETE /orders/1
  def destroy
    @order.destroy
    redirect_to my_orders_url, notice: 'Order was successfully destroyed.'
  end

  private
  
  def order_params_include_corrected_qty?
    order_params && 
      order_params["order_items_attributes"] && 
      order_params["order_items_attributes"]["0"] && 
      order_params["order_items_attributes"]["0"]["corrected_qty"].present? 
  end
  
  def corrected_qty_update_only_for_expired_offer
    if order_params_include_corrected_qty? && !@offer.expired?
      raise "[OrdersController#corrected_qty_update_only_for_expired_offer]"
    end
  end
  
  def offer_from_current_user?
    !!((current_user.offers.size > 0) && current_user.offers.find(params[:offer_id]))
  end
  
  def order_from_current_user?
    !!current_user.orders.find(params[:id])
  end
  
  def order_from_current_users_offer?
    # current_user.offers.includes(:orders).where("orders.id = ?", params[:id]).references(:orders)
    !!((current_user.orders.size > 0) && current_user.orders.find(params[:id]))
  end
  
  def current_user_is_admin
    raise "[OrdersController#admin] current_user is not admin" unless current_user.admin
  end

  def current_user_can_see_orders
    raise "[OrdersController#current_user_can_see_orders]" unless offer_from_current_user?
  end

  def current_user_can_see_order
    raise "[OrdersController#current_user_can_see_order]" unless order_from_current_users_offer?
  end

  def current_user_can_write
    raise "[OrdersController#current_user_can_write]" unless order_from_current_user?
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_order
    @offer = Offer.find(params[:offer_id])
    @order = Order.find(params[:id])
  end

  # Only allow a trusted parameter "white list" through.
  def order_params
    params.require(:order).permit(:offer_id, :user_id, :delivery_id, :note, :status, 
      order_items:            [:id, :_destroy, :offer_item_id, :qty, :qty_description, :status, :corrected_qty],
      order_items_attributes: [:id, :_destroy, :offer_item_id, :qty, :qty_description, :status, :corrected_qty])
  end
end