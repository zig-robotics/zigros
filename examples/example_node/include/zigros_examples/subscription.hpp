#ifndef ZIGROS_EXAMPLES_SUBSCRIPTION_HPP
#define ZIGROS_EXAMPLES_SUBSCRIPTION_HPP

#include "rclcpp/rclcpp.hpp"
#include "zigros_example_interface/msg/example.hpp"
#include "zigros_example_interface/srv/example.hpp"

namespace zigros_examples
{

class Subscription
{
public:
  Subscription(rclcpp::NodeOptions options = rclcpp::NodeOptions());
  rclcpp::Node node_;
  std::shared_ptr<rclcpp::Subscription<zigros_example_interface::msg::Example>> subscription_;
  std::shared_ptr<rclcpp::Client<zigros_example_interface::srv::Example>> client_;
  std::shared_ptr<const zigros_example_interface::msg::Example> prev_msg_;
};
}  // namespace zigros_examples
#endif  // ZIGROS_EXAMPLES_SUBSCRIPTION_HPP
