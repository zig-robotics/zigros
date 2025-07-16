#ifndef ZIGROS_EXAMPLES_SERVICE_HPP
#define ZIGROS_EXAMPLES_SERVICE_HPP

#include "rclcpp/rclcpp.hpp"
#include "zigros_example_interface/srv/example.hpp"

namespace zigros_examples
{

class Service
{
public:
  Service(rclcpp::NodeOptions options = rclcpp::NodeOptions());
  rclcpp::Node node_;
  std::shared_ptr<rclcpp::Service<zigros_example_interface::srv::Example>> server_;
};
}  // namespace zigros_examples
#endif  // ZIGROS_EXAMPLES_SERVICE_HPP
