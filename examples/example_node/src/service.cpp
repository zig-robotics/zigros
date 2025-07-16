#include "zigros_examples/service.hpp"

namespace zigros_examples
{

Service::Service(rclcpp::NodeOptions options)
: node_{"service", options},
  server_{node_.create_service<zigros_example_interface::srv::Example>(
    "example", [this](
                 zigros_example_interface::srv::Example::Request::ConstSharedPtr request,
                 zigros_example_interface::srv::Example::Response::SharedPtr response) {
      response->diff = rclcpp::Time(request->a) - rclcpp::Time(request->b);
    })}
{
}
}  // namespace zigros_examples
