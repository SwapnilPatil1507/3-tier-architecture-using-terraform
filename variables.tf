variable "region" {
  type    = string
  default = "ap-south-1"
}
variable "ins_type" {
  type = string
}
variable "ami" {
  type    = string
  default = "ami-00bb6a80f01f03502"
}
variable "access" {
  type = string
}
variable "secret" {
  type = string
}
variable "db_user" {
  type = string
}
variable "db_pass" {
  type = string
}
