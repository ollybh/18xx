/* global d3 */

function addOffboardNodes(nodes) {
  nodes.append("rect")
    .attr("stroke", "#000000")
    .attr("stroke-width", 2)
    .attr("x", -12)
    .attr("y", -12)
    .attr("width", 24)
    .attr("height", 24)
    .attr("fill", "#ec232a");
  nodes.append("text")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "central")
    .attr("font-size", 12)
    .attr("font-weight", "bold")
    .text(d => d.name);
  nodes.append("title")
    .text(d => d.description);
}

function addCityNodes(nodes) {
  nodes.append("circle")
    .attr("stroke", "#000000")
    .attr("stroke-width", 2)
    .attr("r", 15)
    .attr("fill", "#ffffff");
  nodes.append("text")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "central")
    .attr("font-size", 12)
    .attr("font-weight", "bold")
    .text(d => d.name);
  nodes.append("title")
    .text(d => d.description);
}

function addTownNodes(nodes) {
  nodes.append("circle")
    .attr("stroke", "#000000")
    .attr("stroke-width", 3)
    .attr("r", 8)
    .attr("fill", "#ffffff");
  nodes.append("circle")
    .attr("stroke", "none")
    .attr("r", 4)
    .attr("fill", "#000000");
  nodes.append("title")
    .text(d => d.description);
}

function addJunctionNodes(nodes) {
  nodes.append("circle")
    .attr("stroke", "none")
    .attr("r", 4)
    .attr("fill", "#626569");
  nodes.append("title")
    .text(d => d.description);
}

function addHexEdgeNodes(nodes) {
  // Tracks ending at hex edges
  const ends = nodes.filter((d) => d.connections == 1)
  ends.append("polygon")
    .attr("points", "10,0 5,-8.7 -5,-8.7 -10,0 -5,8.7 5,8.7")
    .attr("stroke", "#000000")
    .attr("stroke-width", 1)
    .attr("fill", "#fde900");
  ends.append("text")
    .attr("text-anchor", "middle")
    .attr("dominant-baseline", "central")
    .attr("font-size", 8)
    .attr("font-weight", "bold")
    .text(d => d.name);
  ends.append("title")
    .text(d => d.description);

  // Gauge changes at hex edges
  const gchange = nodes.filter((d) => d.connections == 2)
  gchange.append("polygon")
    .attr("points", "0,5 4.3,-2.5 -4.3,-2.5")
    .attr("stroke", "none")
    .attr("fill", "#626569");
  gchange.append("title")
    .text(d => d.description);
}

function dashArray(gauge) {
  switch (gauge) {
    case "narrow":
      return "4 2";
    case "broad":
      return "8 2";
    default:
      return "none";
  }
}

function showD3Graph(data) {
  const width = 1000;
  const height = 1000;

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
    .attr("viewBox", [-width / 2, -height / 2, width, height])
    .attr("style", "max-width: 100%; height: 100%;");

  const simulation = d3.forceSimulation(nodes)
    .force("link", d3.forceLink(links).id(d => d.id).iterations(10))
    .force("charge", d3.forceManyBody().strength(-150))
    .force("x", d3.forceX())
    .force("y", d3.forceY());

  const link = svg.append("svg:g")
    .selectAll("line")
    .data(links)
    .enter()
    .append("path")
      .attr("fill", "none")
      .attr("stroke", "#000000")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", d => dashArray(d.gauge));

  link.append("title")
    .text(d => d.gauge);

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
              y1 = d.target.y,
              dr = 50 / d.linkIndex,
              d_line = d.linkIndex ? `A${dr},${dr} 0 0,1 ` : 'L';
        return `M${x0},${y0}${d_line}${x1},${y1}`;
      });
    node
      .attr("transform", d => "translate(" + d.x + "," + d.y + ")");
  });

  document.getElementById("d3_graph").replaceWith(svg.node());
}
