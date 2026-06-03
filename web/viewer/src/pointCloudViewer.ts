import * as THREE from "three";

/**
 * A minimal three.js point-cloud renderer. This is the seam for the real
 * viewer: the next step swaps `setPoints` for a streaming **Potree/COPC** loader
 * (potree-core + loaders.gl) so we can render multi-million-point clouds via
 * octree LOD + HTTP range reads, plus measurement/annotation tools. For now it
 * renders an in-memory buffer so the share-a-scan flow has a working surface.
 */
export class PointCloudViewer {
  private readonly scene = new THREE.Scene();
  private readonly camera: THREE.PerspectiveCamera;
  private readonly renderer: THREE.WebGLRenderer;
  private points?: THREE.Points;
  private frame = 0;

  constructor(canvas: HTMLCanvasElement) {
    const width = canvas.clientWidth || 800;
    const height = canvas.clientHeight || 600;
    this.camera = new THREE.PerspectiveCamera(60, width / height, 0.01, 1000);
    this.camera.position.set(0, 0, 5);
    this.renderer = new THREE.WebGLRenderer({ canvas, antialias: true });
    this.renderer.setSize(width, height, false);
    this.scene.background = new THREE.Color(0x101014);
  }

  /** Replace the rendered cloud. `positions` is xyz-interleaved; optional
   *  `colors` is rgb-interleaved in [0,1]. */
  setPoints(positions: Float32Array, colors?: Float32Array): void {
    if (this.points) {
      this.scene.remove(this.points);
      this.points.geometry.dispose();
    }
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.BufferAttribute(positions, 3));

    let material: THREE.PointsMaterial;
    if (colors) {
      geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
      material = new THREE.PointsMaterial({ size: 0.01, vertexColors: true });
    } else {
      material = new THREE.PointsMaterial({ size: 0.01, color: 0xffffff });
    }
    this.points = new THREE.Points(geometry, material);
    this.scene.add(this.points);
  }

  render(): void {
    if (this.points) {
      this.frame += 1;
      this.points.rotation.y = this.frame * 0.002; // gentle auto-orbit
    }
    this.renderer.render(this.scene, this.camera);
  }

  start(): void {
    const loop = (): void => {
      this.render();
      requestAnimationFrame(loop);
    };
    loop();
  }
}
