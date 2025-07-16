#include "zigros_examples/publisher.hpp"

#include "rclcpp/rclcpp.hpp"
#include "zigros_example_interface/msg/example.hpp"

namespace zigros_examples
{

Publisher::Publisher(rclcpp::NodeOptions options)
: node_{"publisher", options},
  publisher_{node_.create_publisher<zigros_example_interface::msg::Example>("test", 1)},
  timer_{
    rclcpp::create_timer(&node_, node_.get_clock(), rclcpp::Duration::from_seconds(1.0), [this]() {
      auto msg = zigros_example_interface::msg::Example();
      msg.time = node_.now();
      publisher_->publish(msg);
    })}
{
}
}  // namespace zigros_examples
