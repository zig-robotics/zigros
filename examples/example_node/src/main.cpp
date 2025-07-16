#include "zigros_examples/publisher.hpp"
#include "zigros_examples/service.hpp"
#include "zigros_examples/subscription.hpp"

int main(int argc, char * argv[])
{
  rclcpp::init(argc, argv);

  auto node_options = rclcpp::NodeOptions().use_intra_process_comms(true);

  // instantiate your application nodes.
  // this replaces your launch file.
  // all normal launch arguments can be passed using the node options
  auto publisher = zigros_examples::Publisher(node_options);
  auto subscription = zigros_examples::Subscription(node_options);
  auto service = zigros_examples::Service(node_options);

  // For simplicity all nodes are added to the same executor.
  // In a more complex example where parallel execution is required, each node would typically get its own executor and be spun in its own thread.
  // your exact threading structure will depend on your application.
  // Fewer executors/threads will have less overhead, but potentially increae latency.
  // If callbacks depend on each other, they need to be in separate executors.
  auto executor = rclcpp::experimental::executors::EventsExecutor();
  executor.add_node(publisher.node_.get_node_base_interface());
  executor.add_node(subscription.node_.get_node_base_interface());
  executor.add_node(service.node_.get_node_base_interface());
  executor.spin();

  rclcpp::shutdown();
}
