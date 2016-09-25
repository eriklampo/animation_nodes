import bpy
from bpy.props import *
from ... math cimport toPyMatrix4
from ... sockets.info import isList
from ... events import executionCodeChanged
from ... data_structures cimport Matrix4x4List
from ... base_types import AnimationNode, VectorizedSockets

outputItems = [	("BASIS", "Basis", "", "NONE", 0),
                ("LOCAL", "Local", "", "NONE", 1),
                ("PARENT INVERSE", "Parent Inverse", "", "NONE", 2),
                ("WORLD", "World", "", "NONE", 3) ]


class ObjectMatrixOutputNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_ObjectMatrixOutputNode"
    bl_label = "Object Matrix Output"

    outputType = EnumProperty(items = outputItems, update = executionCodeChanged, default = "WORLD")

    def create(self):
        sockets = VectorizedSockets()

        sockets.newInput(self, "Object",
            "Object", "object", {"defaultDrawType" : "PROPERTY_ONLY"},
            "Objects", "objects", {})

        sockets.newInput(self, "Matrix",
            "Matrixaaaaaaa", "matrix", {},
            "Matrices", "matrices", {})

        sockets.newOutput(self, "Object",
            "Object", "object", {},
            "Objects", "objects", {})

        sockets.newConnection(self.inputs[0], self.outputs[0], bothDirections = True)

        self.newSocketEffect(sockets)

    def draw(self, layout):
        row = layout.row(align = True)
        row.prop(self, "outputType", text = "Type")

    def getExecutionFunctionName(self):
        if isList(self.inputs[1].dataType):
            return "execute_List"
        return None

    def getExecutionCode(self):
        indent = ""
        if isList(self.inputs[0].dataType):
            yield "for object in objects:"
            indent = "    "

        t = self.outputType
        yield indent + "if object is not None:"
        if t == "BASIS":          yield indent + "    object.matrix_basis = matrix"
        if t == "LOCAL":          yield indent + "    object.matrix_local = matrix"
        if t == "PARENT INVERSE": yield indent + "    object.matrix_parent_inverse = matrix"
        if t == "WORLD":          yield indent + "    object.matrix_world = matrix"

    def execute_List(self, list objects, Matrix4x4List matrices):
        cdef:
            size_t i
            str attribute = self.outputType
            size_t amount = min(len(objects), len(matrices))
        if attribute == "WORLD":
            for i in range(amount):
                obj = objects[i]
                if obj is not None:
                    obj.matrix_world = toPyMatrix4(matrices.data + i)
        elif attribute == "LOCAL":
            for i in range(amount):
                obj = objects[i]
                if obj is not None:
                    obj.matrix_local = toPyMatrix4(matrices.data + i)
        elif attribute == "PARENT INVERSE":
            for i in range(amount):
                obj = objects[i]
                if obj is not None:
                    obj.matrix_parent_inverse = toPyMatrix4(matrices.data + i)
        elif attribute == "BASIS":
            for i in range(amount):
                obj = objects[i]
                if obj is not None:
                    obj.matrix_basis = toPyMatrix4(matrices.data + i)
        return objects

    def getBakeCode(self):
        if isList(self.inputs[0].dataType):
            yield "for object in objects:"
            yield "    if object is not None:"
            yield "        object.keyframe_insert('location')"
            yield "        object.keyframe_insert('rotation_euler')"
            yield "        object.keyframe_insert('scale')"
        else:
            yield "if object is not None:"
            yield "    object.keyframe_insert('location')"
            yield "    object.keyframe_insert('rotation_euler')"
            yield "    object.keyframe_insert('scale')"
