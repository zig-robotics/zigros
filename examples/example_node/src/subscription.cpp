#include "zigros_examples/subscription.hpp"

namespace zigros_examples
{

Subscription::Subscription(rclcpp::NodeOptions options)
: node_{"subscription", options},
  subscription_{node_.create_subscription<zigros_example_interface::msg::Example>(
    "test", 1,
    [this](zigros_example_interface::msg::Example::ConstSharedPtr msg) {
      RCLCPP_INFO_STREAM(node_.get_logger(), "Time: " << msg->time.sec);
      if (prev_msg_) {
        auto request = std::make_shared<zigros_example_interface::srv::Example::Request>();
        request->a = msg->time;
        request->b = prev_msg_->time;
        client_->async_send_request(
          request,
          [this](rclcpp::Client<zigros_example_interface::srv::Example>::SharedFuture future) {
            if (future.valid()) {
              auto result = future.get();
              RCLCPP_INFO_STREAM(
                node_.get_logger(),
                "Service responce: " << rclcpp::Duration(result->diff).seconds());
            }
          });
      }
      prev_msg_ = msg;
    })},
  client_{node_.create_client<zigros_example_interface::srv::Example>("example")}
{
}
}  // namespace zigros_examples
