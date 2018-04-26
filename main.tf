provider "aws" {
  access_key = "**********************"
  secret_key = "**********************"
  region     = "us-west-2"
}

# Creating Launch configaration

resource "aws_launch_configuration" "alc" {
  image_id = "ami-********"
  instance_type = "t2.micro"
  key_name="aws"
  security_groups=["launch-wizard-1"]
}

# Creating Auto-Scaling Group

resource "aws_autoscaling_group" "scalegroup" {
  launch_configuration = "${aws_launch_configuration.alc.name}"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  min_size = 1
  max_size = 4
  enabled_metrics = ["GroupMinSize", "GroupMaxSize", "GroupDesiredCapacity", "GroupInServiceInstances", "GroupTotalInstances"]
  load_balancers= ["${aws_elb.elb1.id}"]
  health_check_type="ELB"
  metrics_granularity="1Minute"
  tag {
  key = "Name"
  value = "terraform-asg-example"
  propagate_at_launch = true
}
}

# Writing our own policies

resource "aws_autoscaling_policy" "autopolicy" {
name = "terraform-autoplicy"
scaling_adjustment = 1
adjustment_type = "ChangeInCapacity"
cooldown = 300
autoscaling_group_name = "${aws_autoscaling_group.scalegroup.name}"
}

# creating Alarams

resource "aws_cloudwatch_metric_alarm" "cpualarm" {
alarm_name = "terraform-alarm"
comparison_operator = "GreaterThanOrEqualToThreshold"
evaluation_periods = "2"
metric_name = "CPUUtilization"
namespace = "AWS/EC2"
period = "120"
statistic = "Average"
threshold = "60"

dimensions {
AutoScalingGroupName = "${aws_autoscaling_group.scalegroup.name}"
}
alarm_description = "This metric monitor EC2 instance cpu utilization"
alarm_actions = ["${aws_autoscaling_policy.autopolicy.arn}"]
}

# security group for ELB

resource "aws_security_group" "websg" {
name = "security_group_for_web_server"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

lifecycle {
create_before_destroy = true
}
}

resource "aws_security_group_rule" "ssh" {
security_group_id = "${aws_security_group.websg.id}"
type = "ingress"
from_port = 22
to_port = 22
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}
resource "aws_security_group" "elbsg" {
name = "security_group_for_elb"
ingress {
from_port = 80
to_port = 80
protocol = "tcp"
cidr_blocks = ["0.0.0.0/0"]
}

egress {
from_port = 0
to_port = 0
protocol = "-1"
cidr_blocks = ["0.0.0.0/0"]
}
lifecycle {
create_before_destroy = true
}
}

# Creating ELB

resource "aws_elb" "elb1" {
  name = "terraform-elb"
  availability_zones = ["us-west-2a", "us-west-2b", "us-west-2c"]
  security_groups = ["${aws_security_group.elbsg.id}"]
  listener {
  instance_port = 80
  instance_protocol = "http"
  lb_port = 80
  lb_protocol = "http"
  }
  health_check {
  healthy_threshold = 2
  unhealthy_threshold = 2
  timeout = 3
  target = "HTTP:80/"
  interval = 30
 }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400

  tags {
  Name = "terraform-elb"
  }
}

