/* global d3 */

function addOffboardNodes(nodes) {
  nodes.append("rect")
    .attr("class", "offboard")
    .attr("x", -12)
    .attr("y", -12)
    .attr("width", 24)
    .attr("height", 24);
  nodes.append("text")
    .text(d => d.name);
  nodes.append("title")
    .text(d => d.description);
}

function addCityNodes(nodes) {
  nodes.append("circle")
    .attr("class", "city")
    .attr("r", 15);
  nodes.append("text")
    .text(d => d.name);
  nodes.append("title")
    .text(d => d.description);
}

function addTownNodes(nodes) {
  nodes.append("circle")
    .attr("class", "town")
    .attr("r", 8);
  nodes.append("circle")
    .attr("r", 4);
  nodes.append("title")
    .text(d => d.description);
}

function addJunctionNodes(nodes) {
  nodes.append("circle")
    .attr("class", "junction")
    .attr("r", 4)
  nodes.append("title")
    .text(d => d.description);
}

function addHexEdgeNodes(nodes) {
  // Tracks ending at hex edges
  const ends = nodes.filter((d) => d.connections == 1)
  ends.append("polygon")
    .attr("class", "hex")
    .attr("points", "10,0 5,-8.7 -5,-8.7 -10,0 -5,8.7 5,8.7");
  ends.append("text")
    .text(d => d.name);
  ends.append("title")
    .text(d => d.description);

  // Gauge changes at hex edges
  const gchange = nodes.filter((d) => d.connections == 2)
  gchange.append("polygon")
    .attr("class", "edge")
    .attr("points", "0,5 4.3,-2.5 -4.3,-2.5");
  gchange.append("title")
    .text(d => d.description);
}

function viewBoxSize(nodes, svgWidth, svgHeight) {
  const padding = 60;
  let minX = d3.min(nodes, (d) => d.x) - padding;
  let minY = d3.min(nodes, (d) => d.y) - padding;
  let maxX = d3.max(nodes, (d) => d.x) + padding;
  let maxY = d3.max(nodes, (d) => d.y) + padding;
  let viewboxWidth  = maxX - minX;
  let viewboxHeight = maxY - minY;

  // Scale the viewbox to fit its container's aspect ratio.
  const containerRatio = svgWidth / svgHeight;
  const viewboxRatio   = viewboxWidth / viewboxHeight;
  if (viewboxRatio < containerRatio) {
    const targetWidth = viewboxHeight * containerRatio;
    const deficit = targetWidth - viewboxWidth;
    minX -= deficit / 2;
    viewboxWidth = targetWidth;
  } else {
    const targetHeight = viewboxWidth / containerRatio;
    const deficit = targetHeight - viewboxHeight;
    minY -= deficit / 2;
    viewboxHeight = targetHeight;
  }

  return `${minX} ${minY} ${viewboxWidth} ${viewboxHeight}`;
}

function forceStrengths(width, height) {
  const aspectRatio = width / height;
  return { x: 0.08 / aspectRatio, y: 0.08 * aspectRatio };
}

// eslint-disable-next-line @typescript-eslint/no-unused-vars
function showD3Graph(data) {
  let width = data.get("width");
  let height = data.get("height");

  const nodes = data.get("nodes").map(d => Object.fromEntries(d));
  const links = data.get("links").map(d => Object.fromEntries(d));

  // Identify where there are multiple links between two nodes.
  links.forEach((link) => {
    const src = link.source;
    const tgt = link.target;
    const group = links.filter((lnk) =>
      (lnk.source == src && lnk.target == tgt) || (lnk.source == tgt && lnk.target == src)
    );
    group.forEach((l, i) => l.linkIndex = i);
  });

  const svg = d3.create("svg:svg")
    .attr("id", "d3_graph")
    .attr("width", width)
    .attr("height", height)
    .attr("viewBox", [-width / 2, -height / 2, width, height]);

  let strengths = forceStrengths(width, height);

  const simulation = d3.forceSimulation(nodes)
    .force("link", d3.forceLink(links).id(d => d.id).iterations(10))
    .force("charge", d3.forceManyBody().strength(-150))
    .force("collide", d3.forceCollide(20))
    .force("x", d3.forceX().strength(strengths.x))
    .force("y", d3.forceY().strength(strengths.y));

  // Adjust the X/Y forces if the screen resizes, to make the visualisation's
  // shape approximate its container's aspect ratio.
  const container = document.getElementById("route_graph");
  if (container) {
    const observer = new ResizeObserver((entries) => {
      for (const entry of entries) {
        const w = entry.contentRect.width;
        const h = entry.contentRect.height;
        width = w;
        height = h;
        strengths = forceStrengths(w, h);
        simulation.force("x").strength(strengths.x);
        simulation.force("y").strength(strengths.y);
        simulation.alpha(0.3).restart();
      }
    });
    observer.observe(container);
  }

  const link = svg.append("svg:g")
      .attr("class", "links")
    .selectAll("line")
    .data(links)
    .enter()
    .append("path")
      .attr("class", d => d.gauge);

  link.append("title")
    .text(d => `${d.gauge} gauge track, hexes ${d.hexes}`);

  const node = svg.append("svg:g")
      .attr("class", "nodes")
    .selectAll("g")
    .data(nodes)
    .enter()
    .append("g");

  addOffboardNodes(node.filter((d) => d.type == "Offboard"));
  addCityNodes(node.filter((d) => d.type == "City"));
  addTownNodes(node.filter((d) => d.type == "Town"));
  addJunctionNodes(node.filter((d) => d.type == "Junction"));
  addHexEdgeNodes(node.filter((d) => d.type == "Edge"));

  simulation.on("tick", () => {
    link
      .attr("d",  d => {
        const x0 = d.source.x,
              y0 = d.source.y,
              x1 = d.target.x,
              y1 = d.target.y;
        if (d.source === d.target) {
          // This is an edge that loops around a vertex.
          const r = 50;
          return `M${x0},${y0} C${x0 + r},${y0 - r}, ${x0 - r},${y0 - r}, ${x0},${y0}`;
        }
        const dr = 50 / d.linkIndex;
        const d_line = d.linkIndex ? `A${dr},${dr} 0 0,1 ` : 'L';
        return `M${x0},${y0}${d_line}${x1},${y1}`;
      });
    node
      .attr("transform", d => "translate(" + d.x + "," + d.y + ")");

    // At the start of the simulation we don't know how big it is going to
    // get. Adjust the viewport size so it's slightly bigger than the outer
    // vertices.
    svg.attr("viewBox", viewBoxSize(nodes, width, height));
  });

  document.getElementById("d3_graph").replaceWith(svg.node());
}
