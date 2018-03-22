import bpy
from bpy.props import *
from ... data_structures import Mesh
from ... base_types import AnimationNode
from . c_utils import getMatricesAlongSpline
from .. mesh.c_utils import getReplicatedVertices
from ... algorithms.mesh_generation.circle import getPointsOnCircle
from ... algorithms.mesh_generation.grid import quadEdges, quadPolygons

class MeshFromSplineNode(bpy.types.Node, AnimationNode):
    bl_idname = "an_MeshFromSplineNode"
    bl_label = "Mesh from Spline"
    bl_width_default = 160

    useCustomShape = BoolProperty(name = "Use Custom Shape", default = False,
        update = AnimationNode.refresh)

    def create(self):
        self.newInput("Spline", "Spline", "spline", defaultDrawType = "PROPERTY_ONLY")
        self.newInput("Float", "Size", "size", value = 0.3, minValue = 0)
        self.newInput("Boolean", "Cap Ends", "capEnds", value = False)
        self.newInput("Integer", "Spline Resolution", "splineResolution", value = 5, minValue = 0)

        if self.useCustomShape:
            self.newInput("Vector List", "Shape Border", "shapeBorder", dataIsModified = True)
            self.newInput("Boolean", "Closed Shape", "closedShape", value = True)
        else:
            self.newInput("Integer", "Bevel Resolution", "bevelResolution", value = 4, minValue = 2)

        self.newOutput("Mesh", "Mesh", "mesh")

    def draw(self, layout):
        layout.prop(self, "useCustomShape")

    def getExecutionFunctionName(self):
        if self.useCustomShape:
            return "execute_CustomShape"
        else:
            return "execute_CircleShape"

    def execute_CircleShape(self, spline, size, capEnds, splineResolution, bevelResolution):
        size = max(size, 0)
        bevelResolution = max(bevelResolution, 2)
        circlePoints = getPointsOnCircle(bevelResolution, size)
        return self.createSplineMesh(spline, capEnds, splineResolution, circlePoints, True)

    def execute_CustomShape(self, spline, size, capEnds, splineResolution, shapeBorder, closedShape):
        size = max(size, 0)
        shapeBorder.scale(size)
        return self.createSplineMesh(spline, capEnds, splineResolution, shapeBorder, closedShape)

    def createSplineMesh(self, spline, capEnds, splineResolution, shape, closedShape):
        if not spline.isEvaluable() or len(shape) < 2:
            return Mesh()

        splineResolution = max(splineResolution, 0)

        if spline.cyclic:
            amount = len(spline.points) + splineResolution * len(spline.points)
        else:
            amount = len(spline.points) + splineResolution * (len(spline.points) - 1)

        matrices = getMatricesAlongSpline(spline, amount)
        allVertices = getReplicatedVertices(shape, matrices)

        allEdges = quadEdges(amount, len(shape),
            joinVertical = len(shape) > 2 and closedShape,
            joinHorizontal = spline.cyclic)
        allPolygons = quadPolygons(amount, len(shape),
            joinVertical = len(shape) > 2 and closedShape,
            joinHorizontal = spline.cyclic)

        if capEnds and not spline.cyclic and len(shape) > 2:
            allPolygons.append(tuple(range(len(shape))))
            allPolygons.append(tuple(reversed(range((amount - 1) * len(shape), amount * len(shape)))))

        return Mesh(allVertices, allEdges, allPolygons, skipValidation = True)