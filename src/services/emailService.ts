import { supabase } from '../lib/supabase';

export interface EmailTemplate {
  subject: string;
  html: string;
  text: string;
}

export interface EmailData {
  to: string;
  subject: string;
  html: string;
  text: string;
  userId?: string;
  emailType: string;
}

class EmailService {
  private async logEmail(emailData: EmailData, status: 'sent' | 'failed' | 'pending', errorMessage?: string) {
    try {
      await supabase
        .from('email_logs')
        .insert({
          user_id: emailData.userId || null,
          email_type: emailData.emailType,
          recipient_email: emailData.to,
          subject: emailData.subject,
          status,
          error_message: errorMessage
        });
    } catch (error) {
      console.error('Error logging email:', error);
    }
  }

  async sendEmail(emailData: EmailData): Promise<boolean> {
    try {
      // Log email as pending
      await this.logEmail(emailData, 'pending');

      // In production, integrate with email service like SendGrid, Mailgun, or AWS SES
      // For demo, we'll simulate sending
      console.log('Sending email:', emailData);
      
      // Simulate API call
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // Simulate success/failure (90% success rate)
      const success = Math.random() > 0.1;
      
      if (success) {
        await this.logEmail(emailData, 'sent');
        return true;
      } else {
        await this.logEmail(emailData, 'failed', 'Simulated email service error');
        return false;
      }
    } catch (error) {
      console.error('Error sending email:', error);
      await this.logEmail(emailData, 'failed', error instanceof Error ? error.message : 'Unknown error');
      return false;
    }
  }

  // Email Templates
  getOrderConfirmationTemplate(orderData: any): EmailTemplate {
    const subject = `Order Confirmation - ${orderData.id}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #f59e0b, #d97706); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0;">Order Confirmed!</h1>
          <p style="color: #fef3c7; margin: 10px 0 0 0;">Thank you for your order with GiftFlare</p>
        </div>
        
        <div style="padding: 30px; background: white;">
          <h2 style="color: #92400e;">Order Details</h2>
          <p><strong>Order ID:</strong> ${orderData.id}</p>
          <p><strong>Total Amount:</strong> ₹${(orderData.total_amount / 100).toLocaleString()}</p>
          <p><strong>Delivery Type:</strong> ${orderData.delivery_type === 'instant' ? 'Instant Delivery (2-4 hours)' : 'Standard Delivery (3-7 days)'}</p>
          
          <h3 style="color: #92400e; margin-top: 30px;">Items Ordered</h3>
          ${orderData.items.map((item: any) => `
            <div style="border: 1px solid #fde68a; padding: 15px; margin: 10px 0; border-radius: 8px;">
              <p><strong>${item.product.name}</strong></p>
              <p>Quantity: ${item.quantity} × ₹${item.product.price.toLocaleString()}</p>
              <p>Seller: ${item.product.sellerName}</p>
              ${item.giftPackaging ? '<p style="color: #d97706;"><strong>🎁 Gift Packaging Included</strong></p>' : ''}
              ${item.giftNote ? `<p style="color: #92400e;"><em>Gift Note: "${item.giftNote}"</em></p>` : ''}
            </div>
          `).join('')}
          
          <div style="background: #fef3c7; padding: 20px; margin: 30px 0; border-radius: 8px;">
            <h3 style="color: #92400e; margin: 0 0 10px 0;">What's Next?</h3>
            <p style="margin: 5px 0;">✅ We'll prepare your order with care</p>
            <p style="margin: 5px 0;">📦 You'll receive shipping updates via email and SMS</p>
            <p style="margin: 5px 0;">🚚 Track your order in the GiftFlare app</p>
          </div>
          
          <p style="color: #6b7280; font-size: 14px; margin-top: 30px;">
            If you have any questions, please contact our support team.
          </p>
        </div>
      </div>
    `;
    
    const text = `
      Order Confirmed!
      
      Thank you for your order with GiftFlare.
      
      Order ID: ${orderData.id}
      Total Amount: ₹${(orderData.total_amount / 100).toLocaleString()}
      Delivery Type: ${orderData.delivery_type === 'instant' ? 'Instant Delivery (2-4 hours)' : 'Standard Delivery (3-7 days)'}
      
      Items Ordered:
      ${orderData.items.map((item: any) => `
        - ${item.product.name}
          Quantity: ${item.quantity} × ₹${item.product.price.toLocaleString()}
          Seller: ${item.product.sellerName}
          ${item.giftPackaging ? 'Gift Packaging: Yes' : ''}
          ${item.giftNote ? `Gift Note: "${item.giftNote}"` : ''}
      `).join('\n')}
      
      We'll send you updates as your order progresses.
    `;

    return { subject, html, text };
  }

  getShippingUpdateTemplate(orderData: any, trackingNumber: string): EmailTemplate {
    const subject = `Your Order is on the Way! - ${orderData.id}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #10b981, #059669); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0;">📦 Order Shipped!</h1>
          <p style="color: #d1fae5; margin: 10px 0 0 0;">Your handmade treasures are on their way</p>
        </div>
        
        <div style="padding: 30px; background: white;">
          <h2 style="color: #065f46;">Shipping Details</h2>
          <p><strong>Order ID:</strong> ${orderData.id}</p>
          <p><strong>Tracking Number:</strong> ${trackingNumber}</p>
          <p><strong>Estimated Delivery:</strong> ${orderData.estimated_delivery ? new Date(orderData.estimated_delivery).toLocaleDateString() : 'Will be updated soon'}</p>
          
          <div style="background: #ecfdf5; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #10b981;">
            <h3 style="color: #065f46; margin: 0 0 10px 0;">Track Your Package</h3>
            <p style="margin: 0;">Use tracking number <strong>${trackingNumber}</strong> to track your shipment.</p>
          </div>
          
          <p style="color: #6b7280; font-size: 14px; margin-top: 30px;">
            You'll receive another email when your order is delivered.
          </p>
        </div>
      </div>
    `;
    
    const text = `
      Order Shipped!
      
      Your order ${orderData.id} has been shipped.
      
      Tracking Number: ${trackingNumber}
      Estimated Delivery: ${orderData.estimated_delivery ? new Date(orderData.estimated_delivery).toLocaleDateString() : 'Will be updated soon'}
      
      Use the tracking number to monitor your shipment progress.
    `;

    return { subject, html, text };
  }

  getDeliveryConfirmationTemplate(orderData: any): EmailTemplate {
    const subject = `Order Delivered Successfully! - ${orderData.id}`;
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #8b5cf6, #7c3aed); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0;">🎉 Delivered!</h1>
          <p style="color: #e9d5ff; margin: 10px 0 0 0;">Your order has been delivered successfully</p>
        </div>
        
        <div style="padding: 30px; background: white;">
          <h2 style="color: #581c87;">Thank You for Choosing GiftFlare!</h2>
          <p>Your order <strong>${orderData.id}</strong> has been delivered successfully.</p>
          
          <div style="background: #faf5ff; padding: 20px; margin: 20px 0; border-radius: 8px;">
            <h3 style="color: #581c87; margin: 0 0 15px 0;">What's Next?</h3>
            <p style="margin: 5px 0;">⭐ Rate your experience and products</p>
            <p style="margin: 5px 0;">📸 Share your unboxing on social media</p>
            <p style="margin: 5px 0;">🎁 Browse more unique handmade items</p>
          </div>
          
          <p>We hope you love your handmade treasures! If you have any issues, please contact our support team.</p>
        </div>
      </div>
    `;
    
    const text = `
      Order Delivered!
      
      Your order ${orderData.id} has been delivered successfully.
      
      Thank you for choosing GiftFlare! We hope you love your handmade treasures.
      
      Please rate your experience and share your feedback.
    `;

    return { subject, html, text };
  }

  // Send specific email types
  async sendOrderConfirmation(orderData: any, userEmail: string, userId: string): Promise<boolean> {
    const template = this.getOrderConfirmationTemplate(orderData);
    return this.sendEmail({
      to: userEmail,
      subject: template.subject,
      html: template.html,
      text: template.text,
      userId,
      emailType: 'order_confirmation'
    });
  }

  async sendShippingUpdate(orderData: any, trackingNumber: string, userEmail: string, userId: string): Promise<boolean> {
    const template = this.getShippingUpdateTemplate(orderData, trackingNumber);
    return this.sendEmail({
      to: userEmail,
      subject: template.subject,
      html: template.html,
      text: template.text,
      userId,
      emailType: 'shipping_update'
    });
  }

  async sendDeliveryConfirmation(orderData: any, userEmail: string, userId: string): Promise<boolean> {
    const template = this.getDeliveryConfirmationTemplate(orderData);
    return this.sendEmail({
      to: userEmail,
      subject: template.subject,
      html: template.html,
      text: template.text,
      userId,
      emailType: 'delivery_confirmation'
    });
  }

  async sendSellerApproval(seller: { email: string, name: string, id: string }) {
    const subject = 'Your Seller Account Has Been Approved!';
    const dashboardUrl = `${window.location.origin}/seller/dashboard`;
    const quote = '"Your journey as a creator begins now. Every masterpiece starts with a single step."';
    const html = `
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <div style="background: linear-gradient(135deg, #b8926b, #a67c5a); padding: 30px; text-align: center;">
          <h1 style="color: white; margin: 0;">Congratulations, ${seller.name}!</h1>
          <p style="color: #f4f0e8; margin: 10px 0 0 0;">Your seller journey with Zaryah is set to go! 🎉</p>
        </div>
        <div style="padding: 30px; background: white;">
          <blockquote style="font-style: italic; color: #a67c5a; border-left: 4px solid #b8926b; padding-left: 16px; margin: 0 0 24px 0;">${quote}</blockquote>
          <p>🌟 <strong>Welcome to the Zaryah family!</strong> Your seller account has been approved and you're now ready to share your beautiful handmade creations with customers who truly appreciate authentic craftsmanship.</p>
          
          <div style="background: #faf8f5; padding: 20px; margin: 20px 0; border-radius: 8px; border-left: 4px solid #b8926b;">
            <h3 style="color: #5c4435; margin: 0 0 10px 0;">🚀 Your seller journey starts now:</h3>
            <ul style="margin: 0; padding-left: 20px; color: #5c4435;">
              <li>✨ Access your personalized seller dashboard</li>
              <li>📸 Upload stunning photos of your creations</li>
              <li>💰 Set competitive pricing for your masterpieces</li>
              <li>🛒 Start receiving orders from eager customers</li>
              <li>📊 Track your sales and growing success</li>
              <li>🎯 Build your brand and customer following</li>
            </ul>
          </div>
          
          <div style="margin: 32px 0; text-align: center;">
            <a href="${dashboardUrl}" style="background: #b8926b; color: white; padding: 16px 40px; border-radius: 12px; text-decoration: none; font-size: 18px; font-weight: bold; box-shadow: 0 4px 12px rgba(184, 146, 107, 0.3);">🎨 Access Your Dashboard</a>
          </div>
          
          <div style="background: #f4f0e8; padding: 20px; margin: 20px 0; border-radius: 8px; border: 1px solid #e8ddd0;">
            <h4 style="color: #5c4435; margin: 0 0 15px 0;">💡 Tips for a Successful Journey:</h4>
            <div style="color: #5c4435; font-size: 14px; line-height: 1.6;">
              <p style="margin: 8px 0;">📷 <strong>Showcase your art:</strong> Take bright, clear photos that capture the beauty of your work</p>
              <p style="margin: 8px 0;">✍️ <strong>Tell your story:</strong> Write compelling descriptions that connect with customers</p>
              <p style="margin: 8px 0;">💎 <strong>Value your craft:</strong> Price fairly while honoring the time and skill in your work</p>
              <p style="margin: 8px 0;">💬 <strong>Build relationships:</strong> Respond warmly and promptly to customer messages</p>
              <p style="margin: 8px 0;">📦 <strong>Create experiences:</strong> Package with love - it's part of the gift!</p>
            </div>
          </div>
          
          <div style="background: #e8ddd0; padding: 20px; margin: 20px 0; border-radius: 8px; text-align: center;">
            <h4 style="color: #5c4435; margin: 0 0 10px 0;">🤝 We're here to support you!</h4>
            <p style="color: #5c4435; margin: 0; font-size: 14px;">
              Have questions? Need help getting started? Our support team is ready to help you succeed. 
              <br/>Contact us anytime at support@zaryah.com
            </p>
          </div>
          
          <p style="color: #6b7280; font-size: 14px; margin-top: 30px; text-align: center; font-style: italic;">
            "Every great journey begins with a single step. Today, you take yours with Zaryah." ✨
          </p>
        </div>
      </div>
    `;
    const text = `
Congratulations, ${seller.name}!

Your seller journey with Zaryah is set to go! 🎉

${quote}

Welcome to the Zaryah family! Your seller account has been approved and you're now ready to share your beautiful handmade creations with customers who truly appreciate authentic craftsmanship.

Your seller journey starts now:
• Access your personalized seller dashboard
• Upload stunning photos of your creations
• Set competitive pricing for your masterpieces
• Start receiving orders from eager customers
• Track your sales and growing success
• Build your brand and customer following

Go to your dashboard: ${dashboardUrl}

Tips for a Successful Journey:
• Showcase your art: Take bright, clear photos that capture the beauty of your work
• Tell your story: Write compelling descriptions that connect with customers
• Value your craft: Price fairly while honoring the time and skill in your work
• Build relationships: Respond warmly and promptly to customer messages
• Create experiences: Package with love - it's part of the gift!

We're here to support you! Have questions? Contact us at support@zaryah.com

"Every great journey begins with a single step. Today, you take yours with Zaryah."
    `;
    
    return this.sendEmail({
      to: seller.email,
      subject,
      html,
      text,
      userId: seller.id,
      emailType: 'seller_approval'
    });
  }
}

export { EmailService };

export const emailService = new EmailService();