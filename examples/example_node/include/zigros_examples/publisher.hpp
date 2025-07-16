#ifndef ZIGROS_EXAMPLES_PUBLISHER_HPP
#define ZIGROS_EXAMPLES_PUBLISHER_HPP

#include "rclcpp/rclcpp.hpp"
#include "zigros_example_interface/msg/example.hpp"

namespace zigros_examples
{

class Publisher
{
public:
  Publisher(rclcpp::NodeOptions options = rclcpp::NodeOptions());

  rclcpp::Node node_;
  std::shared_ptr<rclcpp::Publisher<zigros_example_interface::msg::Example>> publisher_;
  std::shared_ptr<rclcpp::TimerBase> timer_;
};
}  // namespace zigros_examples
#endif  // ZIGROS_EXAMPLES_PUBLISHER_HPP
