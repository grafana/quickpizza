// Code generated by protoc-gen-go. DO NOT EDIT.
// versions:
// 	protoc-gen-go v1.35.2
// 	protoc        v5.28.3
// source: proto/quickpizza.proto

package quickpizza

import (
	reflect "reflect"
	sync "sync"

	protoreflect "google.golang.org/protobuf/reflect/protoreflect"
	protoimpl "google.golang.org/protobuf/runtime/protoimpl"
)

const (
	// Verify that this generated code is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(20 - protoimpl.MinVersion)
	// Verify that runtime/protoimpl is sufficiently up-to-date.
	_ = protoimpl.EnforceVersion(protoimpl.MaxVersion - 20)
)

type StatusRequest struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields
}

func (x *StatusRequest) Reset() {
	*x = StatusRequest{}
	mi := &file_proto_quickpizza_proto_msgTypes[0]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *StatusRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*StatusRequest) ProtoMessage() {}

func (x *StatusRequest) ProtoReflect() protoreflect.Message {
	mi := &file_proto_quickpizza_proto_msgTypes[0]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use StatusRequest.ProtoReflect.Descriptor instead.
func (*StatusRequest) Descriptor() ([]byte, []int) {
	return file_proto_quickpizza_proto_rawDescGZIP(), []int{0}
}

type StatusResponse struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Ready bool `protobuf:"varint,1,opt,name=ready,proto3" json:"ready,omitempty"`
}

func (x *StatusResponse) Reset() {
	*x = StatusResponse{}
	mi := &file_proto_quickpizza_proto_msgTypes[1]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *StatusResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*StatusResponse) ProtoMessage() {}

func (x *StatusResponse) ProtoReflect() protoreflect.Message {
	mi := &file_proto_quickpizza_proto_msgTypes[1]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use StatusResponse.ProtoReflect.Descriptor instead.
func (*StatusResponse) Descriptor() ([]byte, []int) {
	return file_proto_quickpizza_proto_rawDescGZIP(), []int{1}
}

func (x *StatusResponse) GetReady() bool {
	if x != nil {
		return x.Ready
	}
	return false
}

type PizzaEvaluationRequest struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	Ingredients []string `protobuf:"bytes,1,rep,name=ingredients,proto3" json:"ingredients,omitempty"`
	Dough       string   `protobuf:"bytes,2,opt,name=dough,proto3" json:"dough,omitempty"`
}

func (x *PizzaEvaluationRequest) Reset() {
	*x = PizzaEvaluationRequest{}
	mi := &file_proto_quickpizza_proto_msgTypes[2]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *PizzaEvaluationRequest) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*PizzaEvaluationRequest) ProtoMessage() {}

func (x *PizzaEvaluationRequest) ProtoReflect() protoreflect.Message {
	mi := &file_proto_quickpizza_proto_msgTypes[2]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use PizzaEvaluationRequest.ProtoReflect.Descriptor instead.
func (*PizzaEvaluationRequest) Descriptor() ([]byte, []int) {
	return file_proto_quickpizza_proto_rawDescGZIP(), []int{2}
}

func (x *PizzaEvaluationRequest) GetIngredients() []string {
	if x != nil {
		return x.Ingredients
	}
	return nil
}

func (x *PizzaEvaluationRequest) GetDough() string {
	if x != nil {
		return x.Dough
	}
	return ""
}

type PizzaEvaluationResponse struct {
	state         protoimpl.MessageState
	sizeCache     protoimpl.SizeCache
	unknownFields protoimpl.UnknownFields

	StarsRating int32 `protobuf:"varint,1,opt,name=stars_rating,json=starsRating,proto3" json:"stars_rating,omitempty"`
}

func (x *PizzaEvaluationResponse) Reset() {
	*x = PizzaEvaluationResponse{}
	mi := &file_proto_quickpizza_proto_msgTypes[3]
	ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
	ms.StoreMessageInfo(mi)
}

func (x *PizzaEvaluationResponse) String() string {
	return protoimpl.X.MessageStringOf(x)
}

func (*PizzaEvaluationResponse) ProtoMessage() {}

func (x *PizzaEvaluationResponse) ProtoReflect() protoreflect.Message {
	mi := &file_proto_quickpizza_proto_msgTypes[3]
	if x != nil {
		ms := protoimpl.X.MessageStateOf(protoimpl.Pointer(x))
		if ms.LoadMessageInfo() == nil {
			ms.StoreMessageInfo(mi)
		}
		return ms
	}
	return mi.MessageOf(x)
}

// Deprecated: Use PizzaEvaluationResponse.ProtoReflect.Descriptor instead.
func (*PizzaEvaluationResponse) Descriptor() ([]byte, []int) {
	return file_proto_quickpizza_proto_rawDescGZIP(), []int{3}
}

func (x *PizzaEvaluationResponse) GetStarsRating() int32 {
	if x != nil {
		return x.StarsRating
	}
	return 0
}

var File_proto_quickpizza_proto protoreflect.FileDescriptor

var file_proto_quickpizza_proto_rawDesc = []byte{
	0x0a, 0x16, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x2f, 0x71, 0x75, 0x69, 0x63, 0x6b, 0x70, 0x69, 0x7a,
	0x7a, 0x61, 0x2e, 0x70, 0x72, 0x6f, 0x74, 0x6f, 0x12, 0x0a, 0x71, 0x75, 0x69, 0x63, 0x6b, 0x70,
	0x69, 0x7a, 0x7a, 0x61, 0x22, 0x0f, 0x0a, 0x0d, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52, 0x65,
	0x71, 0x75, 0x65, 0x73, 0x74, 0x22, 0x26, 0x0a, 0x0e, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52,
	0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x12, 0x14, 0x0a, 0x05, 0x72, 0x65, 0x61, 0x64, 0x79,
	0x18, 0x01, 0x20, 0x01, 0x28, 0x08, 0x52, 0x05, 0x72, 0x65, 0x61, 0x64, 0x79, 0x22, 0x50, 0x0a,
	0x16, 0x50, 0x69, 0x7a, 0x7a, 0x61, 0x45, 0x76, 0x61, 0x6c, 0x75, 0x61, 0x74, 0x69, 0x6f, 0x6e,
	0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x12, 0x20, 0x0a, 0x0b, 0x69, 0x6e, 0x67, 0x72, 0x65,
	0x64, 0x69, 0x65, 0x6e, 0x74, 0x73, 0x18, 0x01, 0x20, 0x03, 0x28, 0x09, 0x52, 0x0b, 0x69, 0x6e,
	0x67, 0x72, 0x65, 0x64, 0x69, 0x65, 0x6e, 0x74, 0x73, 0x12, 0x14, 0x0a, 0x05, 0x64, 0x6f, 0x75,
	0x67, 0x68, 0x18, 0x02, 0x20, 0x01, 0x28, 0x09, 0x52, 0x05, 0x64, 0x6f, 0x75, 0x67, 0x68, 0x22,
	0x3c, 0x0a, 0x17, 0x50, 0x69, 0x7a, 0x7a, 0x61, 0x45, 0x76, 0x61, 0x6c, 0x75, 0x61, 0x74, 0x69,
	0x6f, 0x6e, 0x52, 0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x12, 0x21, 0x0a, 0x0c, 0x73, 0x74,
	0x61, 0x72, 0x73, 0x5f, 0x72, 0x61, 0x74, 0x69, 0x6e, 0x67, 0x18, 0x01, 0x20, 0x01, 0x28, 0x05,
	0x52, 0x0b, 0x73, 0x74, 0x61, 0x72, 0x73, 0x52, 0x61, 0x74, 0x69, 0x6e, 0x67, 0x32, 0xa5, 0x01,
	0x0a, 0x04, 0x47, 0x52, 0x50, 0x43, 0x12, 0x41, 0x0a, 0x06, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73,
	0x12, 0x19, 0x2e, 0x71, 0x75, 0x69, 0x63, 0x6b, 0x70, 0x69, 0x7a, 0x7a, 0x61, 0x2e, 0x53, 0x74,
	0x61, 0x74, 0x75, 0x73, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x1a, 0x2e, 0x71, 0x75,
	0x69, 0x63, 0x6b, 0x70, 0x69, 0x7a, 0x7a, 0x61, 0x2e, 0x53, 0x74, 0x61, 0x74, 0x75, 0x73, 0x52,
	0x65, 0x73, 0x70, 0x6f, 0x6e, 0x73, 0x65, 0x22, 0x00, 0x12, 0x5a, 0x0a, 0x0d, 0x45, 0x76, 0x61,
	0x6c, 0x75, 0x61, 0x74, 0x65, 0x50, 0x69, 0x7a, 0x7a, 0x61, 0x12, 0x22, 0x2e, 0x71, 0x75, 0x69,
	0x63, 0x6b, 0x70, 0x69, 0x7a, 0x7a, 0x61, 0x2e, 0x50, 0x69, 0x7a, 0x7a, 0x61, 0x45, 0x76, 0x61,
	0x6c, 0x75, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x52, 0x65, 0x71, 0x75, 0x65, 0x73, 0x74, 0x1a, 0x23,
	0x2e, 0x71, 0x75, 0x69, 0x63, 0x6b, 0x70, 0x69, 0x7a, 0x7a, 0x61, 0x2e, 0x50, 0x69, 0x7a, 0x7a,
	0x61, 0x45, 0x76, 0x61, 0x6c, 0x75, 0x61, 0x74, 0x69, 0x6f, 0x6e, 0x52, 0x65, 0x73, 0x70, 0x6f,
	0x6e, 0x73, 0x65, 0x22, 0x00, 0x42, 0x15, 0x5a, 0x13, 0x70, 0x6b, 0x67, 0x2f, 0x67, 0x72, 0x70,
	0x63, 0x2f, 0x71, 0x75, 0x69, 0x63, 0x6b, 0x70, 0x69, 0x7a, 0x7a, 0x61, 0x62, 0x06, 0x70, 0x72,
	0x6f, 0x74, 0x6f, 0x33,
}

var (
	file_proto_quickpizza_proto_rawDescOnce sync.Once
	file_proto_quickpizza_proto_rawDescData = file_proto_quickpizza_proto_rawDesc
)

func file_proto_quickpizza_proto_rawDescGZIP() []byte {
	file_proto_quickpizza_proto_rawDescOnce.Do(func() {
		file_proto_quickpizza_proto_rawDescData = protoimpl.X.CompressGZIP(file_proto_quickpizza_proto_rawDescData)
	})
	return file_proto_quickpizza_proto_rawDescData
}

var file_proto_quickpizza_proto_msgTypes = make([]protoimpl.MessageInfo, 4)
var file_proto_quickpizza_proto_goTypes = []any{
	(*StatusRequest)(nil),           // 0: quickpizza.StatusRequest
	(*StatusResponse)(nil),          // 1: quickpizza.StatusResponse
	(*PizzaEvaluationRequest)(nil),  // 2: quickpizza.PizzaEvaluationRequest
	(*PizzaEvaluationResponse)(nil), // 3: quickpizza.PizzaEvaluationResponse
}
var file_proto_quickpizza_proto_depIdxs = []int32{
	0, // 0: quickpizza.GRPC.Status:input_type -> quickpizza.StatusRequest
	2, // 1: quickpizza.GRPC.EvaluatePizza:input_type -> quickpizza.PizzaEvaluationRequest
	1, // 2: quickpizza.GRPC.Status:output_type -> quickpizza.StatusResponse
	3, // 3: quickpizza.GRPC.EvaluatePizza:output_type -> quickpizza.PizzaEvaluationResponse
	2, // [2:4] is the sub-list for method output_type
	0, // [0:2] is the sub-list for method input_type
	0, // [0:0] is the sub-list for extension type_name
	0, // [0:0] is the sub-list for extension extendee
	0, // [0:0] is the sub-list for field type_name
}

func init() { file_proto_quickpizza_proto_init() }
func file_proto_quickpizza_proto_init() {
	if File_proto_quickpizza_proto != nil {
		return
	}
	type x struct{}
	out := protoimpl.TypeBuilder{
		File: protoimpl.DescBuilder{
			GoPackagePath: reflect.TypeOf(x{}).PkgPath(),
			RawDescriptor: file_proto_quickpizza_proto_rawDesc,
			NumEnums:      0,
			NumMessages:   4,
			NumExtensions: 0,
			NumServices:   1,
		},
		GoTypes:           file_proto_quickpizza_proto_goTypes,
		DependencyIndexes: file_proto_quickpizza_proto_depIdxs,
		MessageInfos:      file_proto_quickpizza_proto_msgTypes,
	}.Build()
	File_proto_quickpizza_proto = out.File
	file_proto_quickpizza_proto_rawDesc = nil
	file_proto_quickpizza_proto_goTypes = nil
	file_proto_quickpizza_proto_depIdxs = nil
}